# frozen_string_literal: true

require "json"

module Cascalho
  module Repos
    # Invoices, numbered per profile with no gaps.
    class InvoiceRepo
      include Deps["db.gateway"]

      def db = gateway.connection

      # Takes the profile's next number and yields it; the block returns the
      # params and PDF to store, or nil to leave the number unused.
      def create(profile_id)
        db.transaction do
          number = db[:profiles].where(id: profile_id).get(:next_invoice_number)
          params, pdf = yield(number)
          raise Sequel::Rollback unless params

          db[:profiles].where(id: profile_id).update(next_invoice_number: number + 1)
          id = db[:invoices].insert(profile_id: profile_id, number: number, params: JSON.generate(params),
                                    pdf: Sequel.blob(pdf), created_at: Time.now)
          {id: id, number: number}
        end
      end

      # The invoice, if it belongs to one of the user's profiles.
      def find(user_id, id)
        db[:invoices].join(:profiles, id: :profile_id)
                     .where(Sequel[:profiles][:user_id] => user_id, Sequel[:invoices][:id] => id)
                     .select_all(:invoices).first
      end

      def present(row) = {id: row[:id], profile_id: row[:profile_id], number: row[:number],
                          params: JSON.parse(row[:params])}
    end
  end
end
