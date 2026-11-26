# frozen_string_literal: true

require "base64"

module Cascalho
  module Actions
    module Invoices
      # Creates an invoice from params, optionally over a template. The
      # number is the profile's next one, whatever the params say.
      class Create < Cascalho::Action
        include Deps["repos.profile_repo", "repos.template_repo", "repos.invoice_repo", "native.invoices"]

        def handle(request, response)
          session = authenticate!(request)
          profile = profile_repo.find(session[:user_id], request.params[:id].to_i)
          return not_found(response, "profile") unless profile

          input = json_body(request)
          params = input["params"]
          return render_error(response, 422, "input", "params must be an object") unless params.is_a?(Hash)

          if input["template_id"]
            base = template_repo.body(profile[:id], input["template_id"], "invoice")
            return not_found(response, "invoice template") unless base

            params = DeepMerge.call(base, params)
          end

          error = nil
          created = invoice_repo.create(profile[:id]) do |number|
            numbered = DeepMerge.call(params, {"invoice" => {"number" => number}})
            ok, out = invoices.call("invoices_render", numbered)
            unless ok
              error = out["error"]
              next nil
            end

            [numbered, Base64.strict_decode64(out.fetch("pdf_b64"))]
          end
          return render_error(response, 422, error["code"], error["message"]) unless created

          render_json(response, 201, created)
        end
      end
    end
  end
end
