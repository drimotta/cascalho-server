# frozen_string_literal: true

module Cascalho
  module Actions
    module Invoices
      class Show < Cascalho::Action
        include Deps["repos.invoice_repo"]

        def handle(request, response)
          session = authenticate!(request)
          invoice = invoice_repo.find(session[:user_id], request.params[:id].to_i)
          return not_found(response, "invoice") unless invoice

          render_json(response, 200, invoice_repo.present(invoice))
        end
      end
    end
  end
end
