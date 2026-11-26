# frozen_string_literal: true

module Cascalho
  module Actions
    module Profiles
      # Sets a profile's display name and settings (such as dps_serie).
      class Update < Cascalho::Action
        include Deps["repos.profile_repo"]

        def handle(request, response)
          session = authenticate!(request)
          profile = profile_repo.find(session[:user_id], request.params[:id].to_i)
          return not_found(response, "profile") unless profile

          input = json_body(request)
          name = input["name"]
          settings = input["settings"]
          unless (name.nil? || name.is_a?(String)) && (settings.nil? || settings.is_a?(Hash))
            return render_error(response, 422, "input", "name must be text and settings an object")
          end

          profile_repo.update(profile[:id], name: name, settings: settings)
          render_json(response, 200, profile_repo.find(session[:user_id], profile[:id]))
        end
      end
    end
  end
end
