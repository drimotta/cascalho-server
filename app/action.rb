# auto_register: false
# frozen_string_literal: true

require "hanami/action"
require "dry/monads"
require "json"

module Cascalho
  class Action < Hanami::Action
    include Dry::Monads[:result]
    include Deps["repos.session_repo"]

    # Actions that need a logged-in user call `authenticate!` and then use
    # `current_user_id`.
    class Unauthorized < StandardError; end

    handle_exception Unauthorized => :unauthorized

    private

    def authenticate!(request)
      token = request.get_header("HTTP_AUTHORIZATION").to_s[/\ABearer (\h{64})\z/, 1]
      session = token && session_repo.find_by_token(token)
      raise Unauthorized unless session

      session
    end

    def unauthorized(_request, response, _exception)
      render_error(response, 401, "unauthorized", "log in first")
    end

    def render_json(response, status, body)
      response.status = status
      response.format = :json
      response.body = JSON.generate(body)
    end

    def render_error(response, status, code, message)
      render_json(response, status, {error: {code: code, message: message}})
    end
  end
end
