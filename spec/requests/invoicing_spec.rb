# frozen_string_literal: true

RSpec.describe "Invoices and NFS-e", :db, type: :request do
  let(:cpf) { "09471700655" }
  let(:cnpj) { "40356006000110" }
  let!(:token) do
    login_with(*IcpFixtures.leaf(kind: :pf, cpf: cpf))
    first = body["token"]
    pending = login_with(*IcpFixtures.leaf(kind: :pj, cpf: cpf, cnpj: cnpj))
    json_post "/certificates/#{pending["certificate_id"]}/approve", {}, token: first
    first
  end
  let(:pj_profile) do
    json_get "/profiles", token: token
    body["profiles"].find { |p| p["document"] == cnpj }
  end

  def create_invoice(profile_id, params = InvoiceFixtures.params, template_id: nil)
    json_post "/profiles/#{profile_id}/invoices", {params: params, template_id: template_id}.compact, token: token
    body
  end

  def create_dps(invoice_id, content: {}, template_id: nil, environment: "staging")
    json_post "/invoices/#{invoice_id}/dps",
              {environment: environment, content: content, template_id: template_id}.compact, token: token
    body
  end

  def dps_template(profile_id)
    json_post "/profiles/#{profile_id}/templates",
              {kind: "dps", name: "Monthly", body: {reuse_xml: NfseFixtures.xml}}, token: token
    body["id"]
  end

  describe "profiles" do
    it "keeps a name and settings per profile" do
      json_patch "/profiles/#{pj_profile["id"]}", {name: "Drimotta LTDA", settings: {dps_serie: "2"}}, token: token
      expect(last_response.status).to eq(200), last_response.body
      json_get "/profiles", token: token
      updated = body["profiles"].find { |p| p["id"] == pj_profile["id"] }
      expect(updated).to include("name" => "Drimotta LTDA", "settings" => {"dps_serie" => "2"})
    end

    it "does not show another user's profile" do
      other = login_with(*IcpFixtures.leaf(kind: :pf, cpf: "11144477735"))["token"]
      json_patch "/profiles/#{pj_profile["id"]}", {name: "x"}, token: other
      expect(last_response.status).to eq(404)
    end
  end

  describe "invoices" do
    it "numbers invoices per profile and renders the PDF" do
      first = create_invoice(pj_profile["id"])
      expect(last_response.status).to eq(201), last_response.body
      second = create_invoice(pj_profile["id"], InvoiceFixtures.params.merge("invoice" => {"number" => 99, "due" => "2026-12-10"}))
      expect([first["number"], second["number"]]).to eq([1, 2])

      json_get "/invoices/#{second["id"]}/pdf", token: token
      expect(last_response.status).to eq(200)
      expect(last_response.headers["Content-Type"]).to eq("application/pdf")
      expect(last_response.body).to start_with("%PDF-")
    end

    it "starts from a template and lets every field be overridden" do
      json_post "/profiles/#{pj_profile["id"]}/templates",
                {kind: "invoice", name: "Acme", body: InvoiceFixtures.params}, token: token
      template = body["id"]
      invoice = create_invoice(pj_profile["id"], {"customer" => {"name" => "Acme Inc"}}, template_id: template)
      expect(last_response.status).to eq(201), last_response.body
      json_get "/invoices/#{invoice["id"]}", token: token
      expect(body["params"]["customer"]).to eq("name" => "Acme Inc", "details" => "1 Main St\nSpringfield\nUSA")
      expect(body["params"]["items"]).to eq(InvoiceFixtures.params["items"])
    end

    it "reports invalid params without using a number" do
      create_invoice(pj_profile["id"], InvoiceFixtures.params.merge("items" => []))
      expect(last_response.status).to eq(422)
      expect(body["error"]["message"]).to include("items")
      expect(create_invoice(pj_profile["id"])["number"]).to eq(1)
    end
  end

  describe "DPS" do
    let(:invoice) { create_invoice(pj_profile["id"]) }
    let(:template) { dps_template(pj_profile["id"]) }

    it "builds an unsigned DPS with the next number, as the profile" do
      dps = create_dps(invoice["id"], template_id: template)
      expect(last_response.status).to eq(201), last_response.body
      expect(dps).to include("state" => "built", "n_dps" => 1, "serie" => "1", "environment" => "staging")
      expect(dps["dps_id"]).to eq("DPS31062002#{cnpj}00001000000000000001")
      expect(dps["unsigned_xml"]).to include("<prest><CNPJ>#{cnpj}</CNPJ>")
    end

    it "never lets the issuer be someone else" do
      dps = create_dps(invoice["id"], template_id: template, content: {prest: {CNPJ: "12345678000195"}})
      expect(dps["unsigned_xml"]).to include("<CNPJ>#{cnpj}</CNPJ>")
    end

    it "allows one live NFS-e per invoice, and a new number after a rejection" do
      first = create_dps(invoice["id"], template_id: template)
      create_dps(invoice["id"], template_id: template)
      expect(last_response.status).to eq(409)

      json_post "/dps/#{first["id"]}/result", {outcome: "rejected", messages: ["E0004 - Id"]}, token: token
      expect(last_response.status).to eq(200), last_response.body
      expect(body["state"]).to eq("rejected")

      second = create_dps(invoice["id"], template_id: template)
      expect(last_response.status).to eq(201)
      expect(second["n_dps"]).to eq(2)
    end

    it "does not use a number when the content is invalid" do
      create_dps(invoice["id"], content: {})
      expect(last_response.status).to eq(422)
      expect(create_dps(invoice["id"], template_id: template)["n_dps"]).to eq(1)
    end

    it "records an issued NFS-e only for the DPS that was built" do
      dps = create_dps(invoice["id"], template_id: template)
      signed = dps["unsigned_xml"].sub("</infDPS>", "</infDPS><Signature>x</Signature>")
      json_post "/dps/#{dps["id"]}/result",
                {outcome: "issued", signed_xml: signed.sub("Example Corp", "Other Corp"), chave_acesso: "K1",
                 nfse_xml: "<NFSe/>"}, token: token
      expect(last_response.status).to eq(422)

      json_post "/dps/#{dps["id"]}/result",
                {outcome: "issued", signed_xml: signed, chave_acesso: "K1", nfse_xml: "<NFSe/>",
                 pdf_b64: Base64.strict_encode64("%PDF-1.4")}, token: token
      expect(last_response.status).to eq(200), last_response.body
      expect(body).to include("state" => "issued", "chave_acesso" => "K1")

      json_get "/dps/#{dps["id"]}/pdf", token: token
      expect(last_response.body).to eq("%PDF-1.4")

      json_post "/dps/#{dps["id"]}/result", {outcome: "rejected", messages: []}, token: token
      expect(last_response.status).to eq(409)
    end

    it "keeps the signed DPS when the outcome is unknown" do
      dps = create_dps(invoice["id"], template_id: template)
      signed = dps["unsigned_xml"].sub("</infDPS>", "</infDPS><Signature>x</Signature>")
      json_post "/dps/#{dps["id"]}/result", {outcome: "unknown", signed_xml: signed}, token: token
      expect(body["state"]).to eq("unknown")
      json_get "/dps/#{dps["id"]}", token: token
      expect(body["signed_xml"]).to eq(signed)
      create_dps(invoice["id"], template_id: template)
      expect(last_response.status).to eq(409)
    end
  end
end
