# frozen_string_literal: true

module Cascalho
  # Merges JSON-like hashes: objects merge key by key, anything else in the
  # overlay (arrays included) replaces the base value.
  module DeepMerge
    module_function

    def call(base, overlay)
      return overlay unless base.is_a?(Hash) && overlay.is_a?(Hash)

      base.merge(overlay) { |_key, b, o| call(b, o) }
    end
  end
end
