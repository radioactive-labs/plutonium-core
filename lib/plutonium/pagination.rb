# frozen_string_literal: true

module Plutonium
  # Index-page pagination options, shared by the global setting
  # (`config.pagination`) and the per-resource definition DSL (`pagination`).
  #
  # `count:` decides what the index pays to know its total:
  #
  #   :exact  - a full COUNT(*) on every page load (the default)
  #   Integer - count at most this many rows, then show "N+"
  #   false   - no COUNT query at all; prev/next navigation only
  module Pagination
    OPTIONS = %i[count].freeze
    DEFAULTS = {count: :exact}.freeze

    # Validates a partial options hash and returns it frozen. An unknown key or
    # count value raises at declaration, not on the first page load.
    def self.validate!(options)
      raise ArgumentError, "pagination options must be a Hash, got #{options.inspect}" unless options.is_a?(Hash)

      unknown = options.keys - OPTIONS
      raise ArgumentError, "unknown pagination option(s) #{unknown.inspect}, expected #{OPTIONS.inspect}" if unknown.any?

      if options.key?(:count)
        count = options[:count]
        valid = count == :exact || count == false || (count.is_a?(Integer) && count.positive?)
        unless valid
          raise ArgumentError, "pagination count must be :exact, false, or a positive Integer, got #{count.inspect}"
        end
      end

      options.dup.freeze
    end
  end
end
