# frozen_string_literal: true

module Cascalho
  module Actions
    module Templates
      # Saves invoice params (kind "invoice") or DPS content (kind "dps",
      # with optional reuse_xml and content) to start from later.
      class Create < Cascalho::Action
        include Deps["repos.profile_repo", "repos.template_repo"]

        def handle(request, response)
          session = authenticate!(request)
          profile = profile_repo.find(session[:user_id], request.params[:id].to_i)
          return not_found(response, "profile") unless profile

          input = json_body(request)
          kind, name, body = input.values_at("kind", "name", "body")
          unless Repos::TemplateRepo::KINDS.include?(kind) && name.is_a?(String) && !name.empty? && body.is_a?(Hash)
            return render_error(response, 422, "input", "kind (invoice or dps), name and body are required")
          end

          id = template_repo.create(profile[:id], kind: kind, name: name, body: body)
          render_json(response, 201, {id: id, kind: kind, name: name})
        end
      end
    end
  end
end
