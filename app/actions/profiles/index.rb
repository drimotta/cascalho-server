# frozen_string_literal: true

module Cascalho
  module Actions
    module Profiles
      class Index < Cascalho::Action
        include Deps["repos.profile_repo"]

        def handle(request, response)
          session = authenticate!(request)
          render_json(response, 200, {profiles: profile_repo.for_user(session[:user_id])})
        end
      end
    end
  end
end
