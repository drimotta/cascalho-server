# frozen_string_literal: true

require "open3"
require "tmpdir"

# Boots the app as production does, in a fresh process without the test
# helpers' requires, and answers a request. Catches code that only works
# because a spec happened to load a library.
RSpec.describe "Production boot" do
  it "serves a login challenge" do
    Dir.mktmpdir do |dir|
      script = <<~'RUBY'
        require "hanami/boot"
        require "rack/mock"
        Hanami.app["db.gateway"].connection.create_table(:challenges) do
          String :id, primary_key: true
          String :challenge, null: false
          DateTime :expires_at, null: false
          DateTime :used_at
        end
        res = Rack::MockRequest.new(Hanami.app).post("/session/challenge")
        puts "STATUS=#{res.status}"
      RUBY
      env = {"HANAMI_ENV" => "production", "DATABASE_URL" => "sqlite://#{dir}/boot.sqlite",
             "BUNDLE_WITHOUT" => "development:test"}
      out, err, = Open3.capture3(env, "bundle", "exec", "ruby", "-e", script, chdir: File.expand_path("../..", __dir__))
      expect(out.b).to include("STATUS=201"), out.b + err.b
    end
  end
end
