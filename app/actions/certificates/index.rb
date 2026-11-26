# frozen_string_literal: true

module Cascalho
  module Actions
    module Certificates
      class Index < Cascalho::Action
        def handle(request, response)
          session = authenticate!(request)
          list = session_repo.certificates(session[:user_id]).map do |c|
            {id: c[:id], kind: c[:kind], cnpj: c[:cnpj], subject: c[:subject], status: c[:status],
             not_after: c[:not_after].utc.iso8601, approvable_after: c[:approvable_after]&.utc&.iso8601,
             last_used_at: c[:last_used_at]&.utc&.iso8601}
          end
          render_json(response, 200, {certificates: list})
        end
      end
    end
  end
end
