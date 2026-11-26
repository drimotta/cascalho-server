# frozen_string_literal: true

require "cascalho/icp/verifier"

RSpec.describe Cascalho::Icp::Verifier do
  let(:pki) { IcpFixtures.pki }
  let(:crls) { [pki.root_crl, pki.ca_crl] }
  subject(:verifier) { described_class.new(roots: [pki.root], intermediates: [pki.ca], crls: crls) }

  def rejected(der, reason)
    expect { verifier.verify(der) }.to raise_error(described_class::Rejected, reason)
  end

  it "reads the CPF of a personal certificate" do
    cert, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655")
    identity = verifier.verify(cert.to_der)
    expect(identity.kind).to eq(:pf)
    expect(identity.cpf).to eq("09471700655")
    expect(identity.cnpj).to be_nil
    expect(identity.fingerprint).to eq(OpenSSL::Digest::SHA256.hexdigest(cert.to_der))
    expect(identity.not_after).to eq(cert.not_after)
  end

  it "reads the CNPJ and the responsible person's CPF of a company certificate" do
    cert, = IcpFixtures.leaf(kind: :pj, cpf: "09471700655", cnpj: "40356006000110")
    identity = verifier.verify(cert.to_der)
    expect(identity.kind).to eq(:pj)
    expect(identity.cpf).to eq("09471700655")
    expect(identity.cnpj).to eq("40356006000110")
  end

  it "ignores the CN: only the SubjectAltName fields count" do
    cert, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655", name: "OTHER:11111111111")
    expect(verifier.verify(cert.to_der).cpf).to eq("09471700655")
  end

  it "refuses a certificate without the ICP-Brasil fields" do
    cert, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655", san: :none)
    rejected(cert.to_der, /CPF/)
  end

  it "refuses a chain that does not end at a pinned root" do
    other_root_key = IcpFixtures.key
    other_root = IcpFixtures.ca_cert(IcpFixtures.name("Fake AC Raiz v5"), other_root_key)
    other_ca_key = IcpFixtures.key
    other_ca = IcpFixtures.ca_cert(IcpFixtures.name("Fake AC Multipla v5"), other_ca_key,
                                   issuer: other_root, issuer_key: other_root_key)
    cert, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655", issuer: other_ca, issuer_key: other_ca_key)
    rejected(cert.to_der, /chain/)
  end

  it "does not trust intermediates the caller sends" do
    rogue_key = IcpFixtures.key
    rogue = IcpFixtures.ca_cert(IcpFixtures.name("Rogue CA"), rogue_key)
    cert, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655", issuer: rogue, issuer_key: rogue_key)
    expect { verifier.verify(cert.to_der, chain: [rogue.to_der]) }
      .to raise_error(described_class::Rejected, /chain/)
  end

  it "refuses an expired or not yet valid certificate" do
    expired, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655", not_before: Time.now - 7200, not_after: Time.now - 3600)
    rejected(expired.to_der, /expired|valid/)
    future, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655", not_before: Time.now + 3600)
    rejected(future.to_der, /valid/)
  end

  it "refuses a revoked certificate" do
    cert, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655")
    revoked = described_class.new(roots: [pki.root], intermediates: [pki.ca],
                                  crls: [pki.root_crl, IcpFixtures.crl(pki.ca, pki.ca_key, revoked: [cert])])
    expect { revoked.verify(cert.to_der) }.to raise_error(described_class::Rejected, /revoked/)
  end

  it "refuses when the revocation list is missing" do
    cert, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655")
    no_crl = described_class.new(roots: [pki.root], intermediates: [pki.ca], crls: [])
    expect { no_crl.verify(cert.to_der) }.to raise_error(described_class::Rejected, /revocation/)
  end

  it "refuses a certificate without an A3 policy" do
    a1, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655", policy: "2.16.76.1.2.1.10")
    rejected(a1.to_der, /A3/)
    none, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655", policy: nil)
    rejected(none.to_der, /A3/)
  end

  it "refuses a certificate that cannot sign" do
    cert, = IcpFixtures.leaf(kind: :pf, cpf: "09471700655", key_usage: "critical,keyEncipherment")
    rejected(cert.to_der, /digitalSignature/)
  end

  it "refuses garbage" do
    rejected("not a certificate", /certificate/)
  end

  describe "#verify_challenge" do
    let(:pair) { IcpFixtures.leaf(kind: :pf, cpf: "09471700655") }
    let(:challenge) { SecureRandom.bytes(32) }

    it "accepts a signature over the prefix and the challenge" do
      cert, key = pair
      sig = IcpFixtures.sign_challenge(key, challenge)
      expect(verifier.verify_challenge(cert.to_der, challenge, sig)).to be(true)
    end

    it "refuses a signature over the bare challenge or by another key" do
      cert, key = pair
      expect(verifier.verify_challenge(cert.to_der, challenge, key.sign("SHA256", challenge))).to be(false)
      other = IcpFixtures.key.sign("SHA256", "NFSE-LOGIN-V1\n" + challenge)
      expect(verifier.verify_challenge(cert.to_der, challenge, other)).to be(false)
    end
  end
end
