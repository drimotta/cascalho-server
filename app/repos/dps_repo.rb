# frozen_string_literal: true

require "json"

module Cascalho
  module Repos
    # DPS and their outcome at the RFB. A DPS number is used once: it is
    # taken only when the DPS is built, and a rejected DPS keeps its number.
    class DpsRepo
      # The states a result can move a DPS out of.
      OPEN = %w[built unknown].freeze

      include Deps["db.gateway"]

      def db = gateway.connection

      # The invoice's DPS that is not rejected, if any.
      def live_for_invoice(invoice_id)
        db[:dps].where(invoice_id: invoice_id).exclude(state: "rejected").first
      end

      # Takes the next number of the series and yields it; the block returns
      # {dps_id:, xml:} or nil to leave the number unused.
      def create(profile_id:, invoice_id:, environment:, serie:)
        db.transaction do
          key = {profile_id: profile_id, environment: environment, serie: serie}
          number = db[:dps_counters].where(key).get(:next_number) || 1
          built = yield(number)
          raise Sequel::Rollback unless built

          if number == 1 && db[:dps_counters].where(key).empty?
            db[:dps_counters].insert(key.merge(next_number: 2))
          else
            db[:dps_counters].where(key).update(next_number: number + 1)
          end
          now = Time.now
          db[:dps].insert(key.merge(invoice_id: invoice_id, n_dps: number, dps_id: built.fetch(:dps_id),
                                    state: "built", unsigned_xml: built.fetch(:xml), created_at: now,
                                    updated_at: now))
        end
      end

      def find(user_id, id)
        db[:dps].join(:profiles, id: :profile_id)
                .where(Sequel[:profiles][:user_id] => user_id, Sequel[:dps][:id] => id)
                .select_all(:dps).first
      end

      # Records a result if the DPS is still open; returns false otherwise.
      def record(id, state:, **fields)
        fields[:messages] = JSON.generate(fields[:messages]) if fields.key?(:messages)
        fields[:pdf] = Sequel.blob(fields[:pdf]) if fields[:pdf]
        db[:dps].where(id: id, state: OPEN).update(fields.merge(state: state, updated_at: Time.now)) == 1
      end

      def present(row)
        {id: row[:id], invoice_id: row[:invoice_id], state: row[:state], environment: row[:environment],
         serie: row[:serie], n_dps: row[:n_dps], dps_id: row[:dps_id], unsigned_xml: row[:unsigned_xml],
         signed_xml: row[:signed_xml], chave_acesso: row[:chave_acesso], nfse_xml: row[:nfse_xml],
         messages: row[:messages] ? JSON.parse(row[:messages]) : [], has_pdf: !row[:pdf].nil?}
      end
    end
  end
end
