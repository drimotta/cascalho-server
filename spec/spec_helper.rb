# frozen_string_literal: true

require "pathname"
SPEC_ROOT = Pathname(__dir__).realpath.freeze

ENV["HANAMI_ENV"] ||= "test"

# The fake ICP-Brasil hierarchy is the only trust the app gets in tests.
require_relative "support/icp_fixtures"
require "tmpdir"
ENV["ICP_TRUST_DIR"] = IcpFixtures.write_trust_dir(Dir.mktmpdir("icp"))

# The native libraries, from sibling checkouts of drimotta/nfse and
# drimotta/invoices (override with NFSE_DIR / INVOICES_DIR).
so = RUBY_PLATFORM.include?("darwin") ? "dylib" : "so"
ENV["NFSE_DIR"] ||= File.expand_path("../../../nfse", __dir__)
ENV["INVOICES_DIR"] ||= File.expand_path("../../../invoices", __dir__)
ENV["NFSE_LIB"] ||= File.join(ENV["NFSE_DIR"], "target", "debug", "libnfse.#{so}")
ENV["INVOICES_LIB"] ||= File.join(ENV["INVOICES_DIR"], "build", "libinvoices.#{so}")

require "hanami/prepare"

SPEC_ROOT.glob("support/**/*.rb").each { |f| require f }
