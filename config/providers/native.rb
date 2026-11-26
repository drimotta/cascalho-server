# frozen_string_literal: true

# libnfse and libinvoices, loaded once for the process.
Hanami.app.register_provider :native do
  prepare do
    require "cascalho/native"
  end

  start do
    settings = target["settings"]
    register "native.nfse", Cascalho::Native.nfse(settings.nfse_lib)
    register "native.invoices", Cascalho::Native.invoices(settings.invoices_lib)
  end
end
