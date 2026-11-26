# frozen_string_literal: true

module Cascalho
  module Actions
    module Invoices
      class Pdf < Cascalho::Action
        include Deps["repos.invoice_repo"]

        def handle(request, response)
          session = authenticate!(request)
          invoice = invoice_repo.find(session[:user_id], request.params[:id].to_i)
          return not_found(response, "invoice") unless invoice

          send_pdf(response, invoice[:pdf].to_s)
        end
      end
    end
  end
end
