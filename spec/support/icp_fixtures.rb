# frozen_string_literal: true

require "openssl"

# A fake ICP-Brasil hierarchy (root, intermediate, revocation lists) and
# leaf certificates carrying the real ICP-Brasil SubjectAltName fields, for
# tests. Nothing here is trusted outside the test suite.
module IcpFixtures
  PF = "2.16.76.1.3.1"
  CNPJ = "2.16.76.1.3.3"
  RESPONSIBLE_NAME = "2.16.76.1.3.2"
  RESPONSIBLE = "2.16.76.1.3.4"
  A3_POLICY = "2.16.76.1.2.3.10"

  Pki = Struct.new(:root, :root_key, :ca, :ca_key, :root_crl, :ca_crl, keyword_init: true)

  module_function

  def key = OpenSSL::PKey::RSA.new(2048)

  def name(cn, ou = nil)
    parts = [["C", "BR"], ["O", "ICP-Brasil"]]
    parts << ["OU", ou] if ou
    parts << ["CN", cn]
    OpenSSL::X509::Name.new(parts)
  end

  def serial = OpenSSL::BN.rand(64)

  def ca_cert(subject, key, issuer: nil, issuer_key: nil)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = serial
    cert.subject = subject
    cert.issuer = issuer ? issuer.subject : subject
    cert.public_key = key
    cert.not_before = Time.now - 86_400
    cert.not_after = Time.now + (365 * 86_400)
    ef = OpenSSL::X509::ExtensionFactory.new(issuer || cert, cert)
    cert.add_extension(ef.create_extension("basicConstraints", "critical,CA:TRUE"))
    cert.add_extension(ef.create_extension("keyUsage", "critical,keyCertSign,cRLSign"))
    cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash"))
    cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always")) if issuer
    cert.sign(issuer_key || key, "SHA256")
    cert
  end

  def crl(issuer, issuer_key, revoked: [])
    crl = OpenSSL::X509::CRL.new
    crl.version = 1
    crl.issuer = issuer.subject
    crl.last_update = Time.now - 3600
    crl.next_update = Time.now + 86_400
    revoked.each do |cert|
      r = OpenSSL::X509::Revoked.new
      r.serial = cert.serial
      r.time = Time.now - 60
      crl.add_revoked(r)
    end
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.issuer_certificate = issuer
    ef.crl = crl
    crl.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always"))
    crl.add_extension(OpenSSL::X509::Extension.new("crlNumber", OpenSSL::ASN1::Integer.new(1).to_der))
    crl.sign(issuer_key, "SHA256")
    crl
  end

  def pki
    @pki ||= begin
      root_key = key
      root = ca_cert(name("Fake AC Raiz v5", "Instituto Nacional de Tecnologia da Informacao - ITI"), root_key)
      ca_key = key
      ca = ca_cert(name("Fake AC Multipla v5"), ca_key, issuer: root, issuer_key: root_key)
      Pki.new(root: root, root_key: root_key, ca: ca, ca_key: ca_key,
              root_crl: crl(root, root_key), ca_crl: crl(ca, ca_key))
    end
  end

  # An ICP-Brasil person field: birth date (DDMMYYYY), CPF, NIS, RG and its
  # issuer, fixed width.
  def person_field(cpf, birth: "01011990")
    birth + cpf + ("0" * 11) + ("0" * 15) + ("0" * 6)
  end

  def other_name(oid, value)
    OpenSSL::ASN1::ASN1Data.new(
      [OpenSSL::ASN1::ObjectId.new(oid),
       OpenSSL::ASN1::ASN1Data.new([OpenSSL::ASN1::OctetString.new(value)], 0, :CONTEXT_SPECIFIC)],
      0, :CONTEXT_SPECIFIC
    )
  end

  # A leaf certificate. kind :pf takes cpf; kind :pj takes cnpj and the
  # responsible person's cpf.
  def leaf(kind:, cpf:, cnpj: nil, name: "FULANA DE TAL", key: self.key, policy: A3_POLICY,
           not_before: Time.now - 3600, not_after: Time.now + (365 * 86_400),
           issuer: pki.ca, issuer_key: pki.ca_key, key_usage: "critical,digitalSignature,nonRepudiation,keyEncipherment",
           san: :icp)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = serial
    label = kind == :pf ? "#{name}:#{cpf}" : "#{name} LTDA:#{cnpj}"
    cert.subject = name("#{label}", "Certificado #{kind.to_s.upcase} A3")
    cert.issuer = issuer.subject
    cert.public_key = key
    cert.not_before = not_before
    cert.not_after = not_after
    ef = OpenSSL::X509::ExtensionFactory.new(issuer, cert)
    cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE"))
    cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash"))
    cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always"))
    cert.add_extension(ef.create_extension("keyUsage", key_usage))
    cert.add_extension(ef.create_extension("extendedKeyUsage", "clientAuth,emailProtection"))
    if policy
      der = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::ObjectId.new(policy)])]).to_der
      cert.add_extension(OpenSSL::X509::Extension.new("certificatePolicies", der))
    end
    names = case kind
            when :pf then [other_name(PF, person_field(cpf))]
            when :pj then [other_name(RESPONSIBLE_NAME, name), other_name(RESPONSIBLE, person_field(cpf)),
                           other_name(CNPJ, cnpj)]
            end
    if san == :icp
      cert.add_extension(OpenSSL::X509::Extension.new("subjectAltName", OpenSSL::ASN1::Sequence.new(names).to_der))
    end
    cert.sign(issuer_key, "SHA256")
    [cert, key]
  end

  # Writes the hierarchy as the app reads it: roots/, intermediates/ and
  # crls/ with PEM files. Returns the directory.
  def write_trust_dir(dir)
    %w[roots intermediates crls].each { |d| Dir.mkdir(File.join(dir, d)) }
    File.write(File.join(dir, "roots", "root.pem"), pki.root.to_pem)
    File.write(File.join(dir, "intermediates", "ca.pem"), pki.ca.to_pem)
    File.write(File.join(dir, "crls", "root.pem"), pki.root_crl.to_pem)
    File.write(File.join(dir, "crls", "ca.pem"), pki.ca_crl.to_pem)
    dir
  end

  # Signs a login challenge the way libnfse does.
  def sign_challenge(key, challenge, prefix: "NFSE-LOGIN-V1\n")
    key.sign("SHA256", prefix + challenge)
  end
end
