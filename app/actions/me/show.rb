# frozen_string_literal: true

module Cascalho
  module Actions
    module Me
      class Show < Cascalho::Action
        include Deps["repos.profile_repo"]

        def handle(request, response)
          session = authenticate!(request)
          user = session_repo.user(session[:user_id])
          render_json(response, 200, {user: {cpf: user[:cpf]}, profiles: profile_repo.for_user(user[:id])})
        end
      end
    end
  end
end
