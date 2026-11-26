# frozen_string_literal: true

require "openssl"

module Cascalho
  module Icp
    # Checks an ICP-Brasil A3 certificate against pinned roots and current
    # revocation lists, and reads who it belongs to from its SubjectAltName
    # fields (DOC-ICP-04), never from its CN.
    class Verifier
      class Rejected < StandardError; end

      PF = "2.16.76.1.3.1"
      CNPJ = "2.16.76.1.3.3"
      RESPONSIBLE = "2.16.76.1.3.4"
      A3_POLICY_PREFIX = "2.16.76.1.2.3."
      CHALLENGE_PREFIX = "NFSE-LOGIN-V1\n"

      Identity = Struct.new(:kind, :cpf, :cnpj, :fingerprint, :not_after, :subject, keyword_init: true)

      CHAIN_ERRORS = {
        OpenSSL::X509::V_ERR_CERT_HAS_EXPIRED => "the certificate has expired",
        OpenSSL::X509::V_ERR_CERT_NOT_YET_VALID => "the certificate is not valid yet",
        OpenSSL::X509::V_ERR_CERT_REVOKED => "the certificate is revoked",
        OpenSSL::X509::V_ERR_UNABLE_TO_GET_CRL => "no current revocation list for the issuer",
        OpenSSL::X509::V_ERR_CRL_HAS_EXPIRED => "the revocation list is out of date"
      }.freeze

      # roots: the ICP-Brasil roots to trust (and nothing else);
      # intermediates: the ICP-Brasil CAs below them; crls: their current
      # revocation lists.
      def initialize(roots:, intermediates:, crls:, now: -> { Time.now })
        @roots = roots
        @intermediates = intermediates
        @crls = crls
        @now = now
      end

      # Returns the Identity of a certificate (DER), or raises Rejected.
      # A chain sent along by the caller is ignored: only configured
      # intermediates are used.
      def verify(der, chain: nil) # rubocop:disable Lint/UnusedMethodArgument
        cert = parse(der)
        check_chain(cert)
        check_usage(cert)
        identity(cert, der)
      end

      # True when signature is the certificate key's RSA-SHA256 signature of
      # the login prefix followed by the challenge.
      def verify_challenge(der, challenge, signature)
        parse(der).public_key.verify("SHA256", signature, CHALLENGE_PREFIX + challenge)
      rescue OpenSSL::PKey::PKeyError, Rejected
        false
      end

      private

      def parse(der)
        OpenSSL::X509::Certificate.new(der)
      rescue OpenSSL::X509::CertificateError, TypeError
        raise Rejected, "not a certificate"
      end

      def check_chain(cert)
        store = OpenSSL::X509::Store.new
        @roots.each { |r| store.add_cert(r) }
        @crls.each { |c| store.add_crl(c) }
        store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK | OpenSSL::X509::V_FLAG_CRL_CHECK_ALL |
                      OpenSSL::X509::V_FLAG_X509_STRICT
        store.time = @now.call
        ctx = OpenSSL::X509::StoreContext.new(store, cert, @intermediates)
        return if ctx.verify

        raise Rejected, CHAIN_ERRORS.fetch(ctx.error) { "the chain does not lead to a trusted root (#{ctx.error_string})" }
      end

      def extension(cert, name)
        cert.extensions.find { |e| e.oid == name }
      end

      def check_usage(cert)
        ku = extension(cert, "keyUsage")
        raise Rejected, "the certificate cannot sign (no digitalSignature)" unless ku&.value&.include?("Digital Signature")

        policies = extension(cert, "certificatePolicies")
        oids = policies ? OpenSSL::ASN1.decode(policies.value_der).value.map { |p| p.value.first.oid } : []
        raise Rejected, "not an A3 certificate" unless oids.any? { |o| o.start_with?(A3_POLICY_PREFIX) }
      end

      def other_names(cert)
        san = extension(cert, "subjectAltName")
        return {} unless san

        OpenSSL::ASN1.decode(san.value_der).value.each_with_object({}) do |name, found|
          next unless name.tag_class == :CONTEXT_SPECIFIC && name.tag.zero? && name.value.is_a?(Array)

          oid, wrapped = name.value
          inner = wrapped.value.is_a?(Array) ? wrapped.value.first : wrapped
          found[oid.oid] = inner.value.to_s if inner.respond_to?(:value)
        end
      rescue OpenSSL::ASN1::ASN1Error
        {}
      end

      def digits(text, from, size)
        part = text.to_s[from, size]
        part if part&.match?(/\A\d{#{size}}\z/) && part != "0" * size
      end

      def identity(cert, der)
        names = other_names(cert)
        base = {fingerprint: OpenSSL::Digest::SHA256.hexdigest(der), not_after: cert.not_after,
                subject: cert.subject.to_s(OpenSSL::X509::Name::RFC2253)}
        if names.key?(CNPJ)
          cnpj = digits(names[CNPJ], 0, 14)
          cpf = digits(names[RESPONSIBLE], 8, 11)
          raise Rejected, "no CNPJ or responsible CPF in the certificate" unless cnpj && cpf

          Identity.new(kind: :pj, cpf: cpf, cnpj: cnpj, **base)
        else
          cpf = digits(names[PF], 8, 11)
          raise Rejected, "no CPF in the certificate" unless cpf

          Identity.new(kind: :pf, cpf: cpf, cnpj: nil, **base)
        end
      end
    end
  end
end
