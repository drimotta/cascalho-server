# frozen_string_literal: true

require "cascalho/native"

RSpec.describe Cascalho::Native do
  let(:nfse) { described_class.nfse(ENV.fetch("NFSE_LIB")) }
  let(:invoices) { described_class.invoices(ENV.fetch("INVOICES_LIB")) }

  it "builds an unsigned DPS through libnfse" do
    ok, resp = nfse.call("nfse_build_dps", {environment: "staging", serie: "1", n_dps: "5",
                                            reuse_xml: NfseFixtures.xml})
    expect(ok).to be(true), resp.inspect
    expect(resp["id"]).to end_with("00001000000000000005")
    expect(resp["xml"]).to include("<nDPS>5</nDPS>")
  end

  it "returns libnfse errors as data" do
    ok, resp = nfse.call("nfse_build_dps", {environment: "nowhere"})
    expect(ok).to be(false)
    expect(resp["error"]["code"]).to eq("input")
  end

  it "renders an invoice PDF through libinvoices" do
    ok, resp = invoices.call("invoices_render", InvoiceFixtures.params)
    expect(ok).to be(true), resp.inspect
    expect(Base64.decode64(resp["pdf_b64"])).to start_with("%PDF-")
  end

  it "returns libinvoices validation errors as data" do
    ok, resp = invoices.call("invoices_render", InvoiceFixtures.params.merge("items" => []))
    expect(ok).to be(false)
    expect(resp["error"]["message"]).to include("items")
  end

  it "refuses a missing library clearly" do
    expect { described_class.nfse("/nonexistent/libnfse.so") }.to raise_error(described_class::Missing, /nonexistent/)
  end
end
