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

    def not_found(response, what) = render_error(response, 404, "not_found", "no such #{what}")

    # The request's JSON object with its keys as sent (Hanami's params are
    # symbolized and filtered; documents passed through to the libraries
    # keep their own field names).
    def json_body(request)
      io = request.body
      io.rewind
      text = io.read
      io.rewind
      parsed = text.to_s.empty? ? {} : JSON.parse(text)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end

    def send_pdf(response, bytes)
      response.status = 200
      response.headers["Content-Type"] = "application/pdf"
      response.body = bytes
    end
  end
end
