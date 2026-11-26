# frozen_string_literal: true

require "json"

module Cascalho
  module Repos
    # Payment profiles: one per CPF or CNPJ a user issues as.
    class ProfileRepo
      include Deps["db.gateway"]

      def db = gateway.connection

      def ensure(user_id, kind, document)
        existing = db[:profiles].where(user_id: user_id, document: document).first
        return existing[:id] if existing

        db[:profiles].insert(user_id: user_id, kind: kind, document: document, created_at: Time.now)
      end

      def for_user(user_id) = db[:profiles].where(user_id: user_id).order(:id).all.map { |p| present(p) }

      def find(user_id, id)
        row = db[:profiles].where(user_id: user_id, id: id).first
        row && present(row)
      end

      def update(id, name: nil, settings: nil)
        fields = {}
        fields[:name] = name if name
        fields[:settings] = JSON.generate(settings) if settings
        db[:profiles].where(id: id).update(fields) unless fields.empty?
      end

      def present(row)
        {id: row[:id], kind: row[:kind], document: row[:document], name: row[:name],
         settings: JSON.parse(row[:settings])}
      end
    end
  end
end
