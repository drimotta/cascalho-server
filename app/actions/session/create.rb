# frozen_string_literal: true

require "base64"

module Cascalho
  module Actions
    module Session
      # Logs in with a signed challenge (POST /session).
      #
      # A user is a CPF. The first certificate seen for a CPF creates the
      # user. Any later new certificate for that CPF waits for approval from
      # an existing session, or for the waiting period to end, so a CA that
      # misissues a certificate for someone's CPF cannot just log in.
      class Create < Cascalho::Action
        include Deps["icp.verifier", "repos.profile_repo"]

        def handle(request, response)
          p = request.params
          challenge = session_repo.take_challenge(p[:challenge_id])
          return render_error(response, 401, "challenge", "unknown, used or expired challenge") unless challenge

          der = decode(p[:certificate_b64])
          signature = decode(p[:signature_b64])
          unless der && signature && verifier.verify_challenge(der, challenge, signature)
            return render_error(response, 401, "signature", "the signature does not match the certificate")
          end

          identity = verifier.verify(der)
          login(identity, response)
        rescue Icp::Verifier::Rejected => e
          render_error(response, 403, "certificate", e.message)
        end

        private

        def decode(text)
          Base64.strict_decode64(text.to_s)
        rescue ArgumentError
          nil
        end

        def login(identity, response)
          user = session_repo.find_user_by_cpf(identity.cpf)
          user_id = user ? user[:id] : session_repo.create_user(identity.cpf)
          cert = session_repo.find_certificate(identity.fingerprint)
          if cert.nil?
            status = user ? "pending" : "approved"
            cert_id = session_repo.add_certificate(user_id, identity, status: status)
            cert = session_repo.certificate(user_id, cert_id)
          end
          return pending(cert, response) unless usable?(cert)

          session_repo.approve_certificate(cert[:id]) if cert[:status] == "pending"
          session_repo.touch_certificate(cert[:id])
          profile_repo.ensure(user_id, "pf", identity.cpf)
          profile_repo.ensure(user_id, "pj", identity.cnpj) if identity.kind == :pj
          token = session_repo.create_session(user_id, cert[:id])
          render_json(response, 201, {token: token, user: {cpf: identity.cpf},
                                      profiles: profile_repo.for_user(user_id)})
        end

        def usable?(cert)
          cert[:status] == "approved" || (cert[:approvable_after] && cert[:approvable_after] <= Time.now)
        end

        def pending(cert, response)
          render_json(response, 202, {status: "pending_approval", certificate_id: cert[:id],
                                      approvable_after: cert[:approvable_after]&.utc&.iso8601})
        end
      end
    end
  end
end
