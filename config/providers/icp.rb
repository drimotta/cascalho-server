# frozen_string_literal: true

Hanami.app.register_provider :icp do
  prepare do
    require "cascalho/icp/verifier"
  end

  start do
    dir = target["settings"].icp_trust_dir
    pems = ->(sub) { Dir[File.join(dir, sub, "*.pem")].sort.map { |f| File.read(f) } }
    certs = ->(sub) { pems.(sub).map { |p| OpenSSL::X509::Certificate.new(p) } }
    register "icp.verifier", Cascalho::Icp::Verifier.new(
      roots: certs.("roots"),
      intermediates: certs.("intermediates"),
      crls: pems.("crls").map { |p| OpenSSL::X509::CRL.new(p) }
    )
  end
end
