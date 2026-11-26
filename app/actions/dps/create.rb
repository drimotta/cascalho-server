# frozen_string_literal: true

module Cascalho
  module Actions
    module Dps
      # Builds the unsigned DPS for an invoice, for the agent to sign and
      # submit. The issuer is always the invoice's profile, and the number is
      # the next one of the profile's series in that environment.
      class Create < Cascalho::Action
        ENVIRONMENTS = %w[staging production].freeze
        ISSUER_FIELDS = %w[CNPJ CPF NIF cNaoNIF].freeze

        include Deps["repos.profile_repo", "repos.template_repo", "repos.invoice_repo", "repos.dps_repo",
                     "native.nfse"]

        def handle(request, response)
          session = authenticate!(request)
          invoice = invoice_repo.find(session[:user_id], request.params[:id].to_i)
          return not_found(response, "invoice") unless invoice

          profile = profile_repo.find(session[:user_id], invoice[:profile_id])
          input = json_body(request)
          environment = input["environment"]
          content = input["content"] || {}
          unless ENVIRONMENTS.include?(environment) && content.is_a?(Hash)
            return render_error(response, 422, "input", "environment (staging or production) and content are required")
          end

          reuse_xml = nil
          if input["template_id"]
            template = template_repo.body(profile[:id], input["template_id"], "dps")
            return not_found(response, "DPS template") unless template

            reuse_xml = template["reuse_xml"]
            content = DeepMerge.call(template["content"] || {}, content)
          end
          if dps_repo.live_for_invoice(invoice[:id])
            return render_error(response, 409, "exists", "this invoice already has a DPS that was not rejected")
          end

          content = as_issuer(content, profile)
          serie = profile[:settings].fetch("dps_serie", "1").to_s
          error = nil
          id = dps_repo.create(profile_id: profile[:id], invoice_id: invoice[:id], environment: environment,
                               serie: serie) do |number|
            ok, out = nfse.call("nfse_build_dps", {environment: environment, serie: serie, n_dps: number.to_s,
                                                   reuse_xml: reuse_xml, content: content}.compact)
            unless ok
              error = out["error"]
              next nil
            end
            {dps_id: out.fetch("id"), xml: out.fetch("xml")}
          end
          return render_error(response, 422, error["code"], error["message"]) unless id

          render_json(response, 201, dps_repo.present(dps_repo.find(session[:user_id], id)))
        end

        private

        def as_issuer(content, profile)
          prest = content["prest"].is_a?(Hash) ? content["prest"] : {}
          prest = prest.reject { |key, _| ISSUER_FIELDS.include?(key) }
          key = profile[:kind] == "pj" ? "CNPJ" : "CPF"
          content.merge("prest" => {key => profile[:document]}.merge(prest))
        end
      end
    end
  end
end
