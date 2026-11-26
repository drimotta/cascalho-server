# frozen_string_literal: true

module Cascalho
  class Routes < Hanami::Routes
    post "/session/challenge", to: "session.challenge"
    post "/session", to: "session.create"
    delete "/session", to: "session.destroy"
    get "/me", to: "me.show"

    get "/certificates", to: "certificates.index"
    post "/certificates/:id/approve", to: "certificates.approve"

    get "/profiles", to: "profiles.index"
    patch "/profiles/:id", to: "profiles.update"
    post "/profiles/:id/templates", to: "templates.create"
    post "/profiles/:id/invoices", to: "invoices.create"

    get "/invoices/:id", to: "invoices.show"
    get "/invoices/:id/pdf", to: "invoices.pdf"
    post "/invoices/:id/dps", to: "dps.create"

    get "/dps/:id", to: "dps.show"
    get "/dps/:id/pdf", to: "dps.pdf"
    post "/dps/:id/result", to: "dps.result"
  end
end
