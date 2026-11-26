# frozen_string_literal: true

module Cascalho
  class Settings < Hanami::Settings
    # The ICP-Brasil trust: roots/, intermediates/ and crls/ holding PEM
    # files. Only these roots are trusted; refresh the CRLs from ITI and the
    # CAs on a schedule.
    setting :icp_trust_dir, default: "config/icp", constructor: Types::String
    # How long a session lasts, and how long a new certificate for a known
    # CPF waits before it can log in without approval.
    setting :session_ttl_hours, default: 12, constructor: Types::Params::Integer
    setting :approval_wait_hours, default: 72, constructor: Types::Params::Integer
    # Shared libraries from drimotta/nfse and drimotta/invoices.
    setting :nfse_lib, default: nil, constructor: Types::String.optional
    setting :invoices_lib, default: nil, constructor: Types::String.optional
  end
end
