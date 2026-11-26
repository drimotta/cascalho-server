# frozen_string_literal: true

# Sample inputs for the native libraries, from their own repositories.
module NfseFixtures
  module_function

  def dir = ENV.fetch("NFSE_DIR")

  def xml = File.read(File.join(dir, "tests", "fixtures", "nfse-ibscbs.xml"))
end

module InvoiceFixtures
  module_function

  def params
    {
      "items" => [{"name" => "Consulting", "price_cents" => 15_000, "qty" => 40}],
      "customer" => {"name" => "Acme Ltd", "details" => "1 Main St\nSpringfield\nUSA"},
      "invoice" => {"number" => 1, "due" => "2026-12-10"},
      "company" => {"name" => "Drimotta", "details" => "Rua A, 10\nBelo Horizonte", "banking" => "Bank X"}
    }
  end
end
