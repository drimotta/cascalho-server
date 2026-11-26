# frozen_string_literal: true

require "json"

module Cascalho
  module Repos
    # Reusable starting points: invoice params or DPS content per profile.
    class TemplateRepo
      KINDS = %w[invoice dps].freeze

      include Deps["db.gateway"]

      def db = gateway.connection

      def create(profile_id, kind:, name:, body:)
        db[:templates].insert(profile_id: profile_id, kind: kind, name: name, body: JSON.generate(body),
                              created_at: Time.now)
      end

      # The template's body, or nil when it is not this profile's or not of
      # this kind.
      def body(profile_id, id, kind)
        row = db[:templates].where(profile_id: profile_id, id: id, kind: kind).first
        row && JSON.parse(row[:body])
      end
    end
  end
end
