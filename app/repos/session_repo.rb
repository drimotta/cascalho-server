# frozen_string_literal: true

require "base64"

require "digest"
require "securerandom"

module Cascalho
  module Repos
    # Challenges, sessions, users and their certificates.
    class SessionRepo
      include Deps["db.gateway", "settings"]

      def db = gateway.connection

      def create_challenge(ttl: 120)
        id = SecureRandom.hex(16)
        challenge = SecureRandom.bytes(32)
        expires_at = Time.now + ttl
        db[:challenges].insert(id: id, challenge: Base64.strict_encode64(challenge), expires_at: expires_at)
        {id: id, challenge: challenge, expires_at: expires_at}
      end

      # Marks the challenge used and returns its bytes, or nil when it is
      # unknown, used or expired.
      def take_challenge(id)
        db.transaction do
          row = db[:challenges].where(id: id.to_s, used_at: nil).where { expires_at > Time.now }.first
          next nil unless row

          db[:challenges].where(id: row[:id]).update(used_at: Time.now)
          Base64.strict_decode64(row[:challenge])
        end
      end

      def find_user_by_cpf(cpf) = db[:users].where(cpf: cpf).first

      def create_user(cpf) = db[:users].insert(cpf: cpf, created_at: Time.now)

      def find_certificate(fingerprint) = db[:certificates].where(fingerprint: fingerprint).first

      def certificate(user_id, id) = db[:certificates].where(user_id: user_id, id: id).first

      def certificates(user_id) = db[:certificates].where(user_id: user_id).order(:id).all

      def add_certificate(user_id, identity, status:)
        db[:certificates].insert(
          user_id: user_id, fingerprint: identity.fingerprint, kind: identity.kind.to_s,
          cnpj: identity.cnpj, subject: identity.subject, not_after: identity.not_after,
          status: status, created_at: Time.now,
          approvable_after: status == "pending" ? Time.now + (settings.approval_wait_hours * 3600) : nil
        )
      end

      def approve_certificate(id)
        db[:certificates].where(id: id).update(status: "approved", approvable_after: nil)
      end

      def touch_certificate(id) = db[:certificates].where(id: id).update(last_used_at: Time.now)

      # Starts a session and returns its token; only its digest is stored.
      def create_session(user_id, certificate_id)
        token = SecureRandom.hex(32)
        db[:sessions].insert(user_id: user_id, certificate_id: certificate_id, token_digest: digest(token),
                             expires_at: Time.now + (settings.session_ttl_hours * 3600), created_at: Time.now)
        token
      end

      def find_by_token(token)
        db[:sessions].where(token_digest: digest(token)).where { expires_at > Time.now }.first
      end

      def delete_session(id) = db[:sessions].where(id: id).delete

      def user(id) = db[:users].where(id: id).first

      private

      def digest(token) = Digest::SHA256.hexdigest(token)
    end
  end
end
