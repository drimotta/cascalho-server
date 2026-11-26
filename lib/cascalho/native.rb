# frozen_string_literal: true

require "fiddle"
require "json"

module Cascalho
  # The C APIs of libnfse and libinvoices: JSON in, a status code and JSON
  # out. Both libraries are loaded into this process, so the server runs as a
  # single Puma process (no forked workers).
  class Native
    class Missing < StandardError; end

    def self.nfse(path) = new(path, free: "nfse_free", functions: %w[nfse_build_dps])

    def self.invoices(path) = new(path, free: "invoices_free", functions: %w[invoices_render])

    def initialize(path, free:, functions:)
      raise Missing, "native library not found: #{path.inspect}" unless path && File.exist?(path)

      lib = Fiddle.dlopen(path)
      @free = Fiddle::Function.new(lib[free], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
      @functions = functions.to_h do |name|
        [name, Fiddle::Function.new(lib[name], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)]
      end
      @lock = Mutex.new
    rescue Fiddle::DLError => e
      raise Missing, "cannot load #{path}: #{e.message}"
    end

    # Returns [ok, response] where response is the parsed JSON.
    def call(name, request)
      fn = @functions.fetch(name)
      out = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP, Fiddle::RUBY_FREE)
      out[0, Fiddle::SIZEOF_VOIDP] = [0].pack("J")
      code, text = @lock.synchronize do
        c = fn.call(JSON.generate(request), out)
        ptr = Fiddle::Pointer.new(out[0, Fiddle::SIZEOF_VOIDP].unpack1("J"))
        t = ptr.null? ? "{}" : ptr.to_s
        @free.call(ptr) unless ptr.null?
        [c, t]
      end
      [code.zero?, JSON.parse(text.force_encoding(Encoding::UTF_8))]
    end
  end
end
