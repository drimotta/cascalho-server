# frozen_string_literal: true

module Cascalho
  module Actions
    module Dps
      # The DANFSe the agent downloaded with the NFS-e.
      class Pdf < Cascalho::Action
        include Deps["repos.dps_repo"]

        def handle(request, response)
          session = authenticate!(request)
          dps = dps_repo.find(session[:user_id], request.params[:id].to_i)
          return not_found(response, "DANFSe") unless dps && dps[:pdf]

          send_pdf(response, dps[:pdf].to_s)
        end
      end
    end
  end
end
