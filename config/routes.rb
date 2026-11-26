# frozen_string_literal: true

module Cascalho
  class Routes < Hanami::Routes
    post "/session/challenge", to: "session.challenge"
    post "/session", to: "session.create"
    delete "/session", to: "session.destroy"
    get "/me", to: "me.show"

    get "/certificates", to: "certificates.index"
    post "/certificates/:id/approve", to: "certificates.approve"
  end
end
