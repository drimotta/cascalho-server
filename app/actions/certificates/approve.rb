# frozen_string_literal: true

module Cascalho
  module Actions
    module Certificates
      # Approves a pending certificate from a session opened with an
      # already approved one.
      class Approve < Cascalho::Action
        def handle(request, response)
          session = authenticate!(request)
          cert = session_repo.certificate(session[:user_id], request.params[:id].to_i)
          return render_error(response, 404, "not_found", "no such certificate") unless cert

          session_repo.approve_certificate(cert[:id])
          render_json(response, 200, {id: cert[:id], status: "approved"})
        end
      end
    end
  end
end
