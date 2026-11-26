# frozen_string_literal: true

module Cascalho
  module Actions
    module Dps
      class Show < Cascalho::Action
        include Deps["repos.dps_repo"]

        def handle(request, response)
          session = authenticate!(request)
          dps = dps_repo.find(session[:user_id], request.params[:id].to_i)
          return not_found(response, "DPS") unless dps

          render_json(response, 200, dps_repo.present(dps))
        end
      end
    end
  end
end
