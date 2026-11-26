# frozen_string_literal: true

require "base64"

module Cascalho
  module Actions
    module Dps
      # What the agent got from the RFB for a DPS: issued, rejected, or
      # unknown (look it up before anything is sent again). An issued or
      # unknown DPS must be the one built here, signed.
      class Result < Cascalho::Action
        include Deps["repos.dps_repo"]

        def handle(request, response)
          session = authenticate!(request)
          dps = dps_repo.find(session[:user_id], request.params[:id].to_i)
          return not_found(response, "DPS") unless dps
          unless Repos::DpsRepo::OPEN.include?(dps[:state])
            return render_error(response, 409, "final", "this DPS is already #{dps[:state]}")
          end

          fields, problem = fields_for(json_body(request), dps)
          return render_error(response, 422, "input", problem) if problem
          return render_error(response, 409, "final", "this DPS changed meanwhile") unless dps_repo.record(dps[:id], **fields)

          render_json(response, 200, dps_repo.present(dps_repo.find(session[:user_id], dps[:id])))
        end

        private

        def fields_for(input, dps)
          case input["outcome"]
          when "issued"
            return [nil, "signed_xml must be the DPS built here, signed"] unless same_dps?(input["signed_xml"], dps)
            return [nil, "chave_acesso and nfse_xml are required"] unless text?(input["chave_acesso"]) && text?(input["nfse_xml"])

            pdf = decode(input["pdf_b64"])
            return [nil, "pdf_b64 is not base64"] if pdf == false

            [{state: "issued", signed_xml: input["signed_xml"], chave_acesso: input["chave_acesso"],
              nfse_xml: input["nfse_xml"], pdf: pdf}.compact]
          when "rejected"
            messages = input["messages"] || []
            return [nil, "messages must be a list of text"] unless messages.is_a?(Array) && messages.all?(String)

            [{state: "rejected", messages: messages}]
          when "unknown"
            return [nil, "signed_xml must be the DPS built here, signed"] unless same_dps?(input["signed_xml"], dps)

            [{state: "unknown", signed_xml: input["signed_xml"]}]
          else
            [nil, "outcome must be issued, rejected or unknown"]
          end
        end

        def text?(value) = value.is_a?(String) && !value.empty?

        # The signature only adds to the DPS: its infDPS must be byte for
        # byte the one that was built.
        def same_dps?(signed, dps)
          inf = dps[:unsigned_xml][%r{<infDPS\b.*</infDPS>}m]
          text?(signed) && inf && signed.include?(inf)
        end

        def decode(b64)
          return nil if b64.nil?

          Base64.strict_decode64(b64)
        rescue ArgumentError
          false
        end
      end
    end
  end
end
