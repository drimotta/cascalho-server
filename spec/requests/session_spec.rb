# frozen_string_literal: true

RSpec.describe "Logging in with a certificate", :db, type: :request do
  let(:cpf) { "09471700655" }
  let(:pf) { IcpFixtures.leaf(kind: :pf, cpf: cpf) }
  let(:pj) { IcpFixtures.leaf(kind: :pj, cpf: cpf, cnpj: "40356006000110") }

  it "issues a single-use challenge" do
    json_post "/session/challenge"
    expect(last_response.status).to eq(201)
    expect(Base64.strict_decode64(body["challenge_b64"]).bytesize).to eq(32)
    expect(body["challenge_id"]).to match(/\A\h{32}\z/)
  end

  it "creates the user and the personal profile on the first login" do
    result = login_with(*pf)
    expect(last_response.status).to eq(201), last_response.body
    expect(result["token"]).to match(/\A\h{64}\z/)
    expect(result["user"]).to eq("cpf" => cpf)
    expect(result["profiles"].map { |p| [p["kind"], p["document"]] }).to eq([["pf", cpf]])

    json_get "/me", token: result["token"]
    expect(last_response.status).to eq(200)
    expect(body["user"]["cpf"]).to eq(cpf)
  end

  it "holds a new certificate for an existing user until a session approves it" do
    first = login_with(*pf)
    pending = login_with(*pj)
    expect(last_response.status).to eq(202), last_response.body
    expect(pending["status"]).to eq("pending_approval")

    json_get "/certificates", token: first["token"]
    listed = body["certificates"].find { |c| c["id"] == pending["certificate_id"] }
    expect(listed).to include("status" => "pending", "kind" => "pj", "cnpj" => "40356006000110")

    json_post "/certificates/#{pending["certificate_id"]}/approve", {}, token: first["token"]
    expect(last_response.status).to eq(200), last_response.body

    second = login_with(*pj)
    expect(last_response.status).to eq(201), last_response.body
    expect(second["profiles"].map { |p| p["document"] }).to contain_exactly(cpf, "40356006000110")
  end

  it "lets a pending certificate in once its waiting period is over" do
    login_with(*pf)
    pending = login_with(*pj)
    Hanami.app["db.gateway"].connection[:certificates].where(id: pending["certificate_id"])
      .update(approvable_after: Time.now - 60)
    login_with(*pj)
    expect(last_response.status).to eq(201), last_response.body
  end

  it "refuses a reused or unknown challenge" do
    cert, key = pf
    json_post "/session/challenge"
    challenge = body
    raw = Base64.strict_decode64(challenge["challenge_b64"])
    attempt = {challenge_id: challenge["challenge_id"], certificate_b64: Base64.strict_encode64(cert.to_der),
               signature_b64: Base64.strict_encode64(IcpFixtures.sign_challenge(key, raw))}
    json_post "/session", attempt
    expect(last_response.status).to eq(201)
    json_post "/session", attempt
    expect(last_response.status).to eq(401)
    json_post "/session", attempt.merge(challenge_id: "0" * 32)
    expect(last_response.status).to eq(401)
  end

  it "refuses an expired challenge" do
    cert, key = pf
    json_post "/session/challenge"
    challenge = body
    Hanami.app["db.gateway"].connection[:challenges].update(expires_at: Time.now - 1)
    raw = Base64.strict_decode64(challenge["challenge_b64"])
    json_post "/session", {challenge_id: challenge["challenge_id"], certificate_b64: Base64.strict_encode64(cert.to_der),
                           signature_b64: Base64.strict_encode64(IcpFixtures.sign_challenge(key, raw))}
    expect(last_response.status).to eq(401)
  end

  it "refuses a signature by another key" do
    cert, = pf
    login_with(cert, IcpFixtures.key)
    expect(last_response.status).to eq(401)
  end

  it "refuses a certificate that fails the ICP-Brasil checks, saying why" do
    login_with(*IcpFixtures.leaf(kind: :pf, cpf: cpf, policy: "2.16.76.1.2.1.10"))
    expect(last_response.status).to eq(403)
    expect(body["error"]["message"]).to match(/A3/)
  end

  it "ends the session" do
    token = login_with(*pf)["token"]
    json_delete "/session", token: token
    expect(last_response.status).to eq(204)
    json_get "/me", token: token
    expect(last_response.status).to eq(401)
  end

  it "requires a session for private endpoints" do
    json_get "/me"
    expect(last_response.status).to eq(401)
    json_get "/me", token: "f" * 64
    expect(last_response.status).to eq(401)
  end
end
