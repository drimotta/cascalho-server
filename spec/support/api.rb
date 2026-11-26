# frozen_string_literal: true

require "base64"
require "json"

# Helpers for the JSON API: requests, responses, and logging in with a
# fixture certificate the way the page and the agent do.
module ApiHelpers
  def json_post(path, body = {}, token: nil)
    header "Authorization", "Bearer #{token}" if token
    post path, JSON.generate(body), "CONTENT_TYPE" => "application/json"
  end

  def json_patch(path, body = {}, token: nil)
    header "Authorization", "Bearer #{token}" if token
    patch path, JSON.generate(body), "CONTENT_TYPE" => "application/json"
  end

  def json_get(path, token: nil)
    header "Authorization", "Bearer #{token}" if token
    get path
  end

  def json_delete(path, token: nil)
    header "Authorization", "Bearer #{token}" if token
    delete path
  end

  def body = JSON.parse(last_response.body)

  # Runs the challenge-response login with a certificate and its key and
  # returns the parsed response.
  def login_with(cert, key)
    json_post "/session/challenge"
    challenge = body
    raw = Base64.strict_decode64(challenge.fetch("challenge_b64"))
    json_post "/session", {
      challenge_id: challenge.fetch("challenge_id"),
      certificate_b64: Base64.strict_encode64(cert.to_der),
      signature_b64: Base64.strict_encode64(IcpFixtures.sign_challenge(key, raw))
    }
    body
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
