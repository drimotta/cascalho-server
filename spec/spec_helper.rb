# frozen_string_literal: true

require "pathname"
SPEC_ROOT = Pathname(__dir__).realpath.freeze

ENV["HANAMI_ENV"] ||= "test"

# The fake ICP-Brasil hierarchy is the only trust the app gets in tests.
require_relative "support/icp_fixtures"
require "tmpdir"
ENV["ICP_TRUST_DIR"] = IcpFixtures.write_trust_dir(Dir.mktmpdir("icp"))

require "hanami/prepare"

SPEC_ROOT.glob("support/**/*.rb").each { |f| require f }
