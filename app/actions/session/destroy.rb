# frozen_string_literal: true

module Cascalho
  module Actions
    module Session
      class Destroy < Cascalho::Action
        def handle(request, response)
          session = authenticate!(request)
          session_repo.delete_session(session[:id])
          response.status = 204
          response.body = ""
        end
      end
    end
  end
end
