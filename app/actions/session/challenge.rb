# frozen_string_literal: true

require "base64"

module Cascalho
  module Actions
    module Session
      # A fresh challenge for the agent to sign (POST /session/challenge).
      class Challenge < Cascalho::Action
        def handle(_request, response)
          c = session_repo.create_challenge
          render_json(response, 201, {challenge_id: c[:id], challenge_b64: Base64.strict_encode64(c[:challenge]),
                                      expires_at: c[:expires_at].utc.iso8601})
        end
      end
    end
  end
end
