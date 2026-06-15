# frozen_string_literal: true

module Plutonium
  # Registry of per-feature migration paths.
  #
  # Features register their migration directory against a configuration key. A
  # path is only surfaced by {.enabled_paths} when its feature's config
  # (+Plutonium.configuration.<feature>+) responds to +.enabled+ and it is true.
  module Migrations
    @registry = {}

    class << self
      # Register a migration path for a feature.
      #
      # @param feature [Symbol, String] the configuration key (e.g. +:wizards+)
      # @param path [String] the absolute migration directory path
      # @return [String] the registered path
      def register(feature, path)
        @registry[feature.to_sym] = path
      end

      # Clear the registry. Intended for tests.
      #
      # @return [Hash]
      def reset!
        @registry = {}
      end

      # Migration paths for features that are currently enabled.
      #
      # @return [Array<String>]
      def enabled_paths
        @registry.filter_map do |feature, path|
          cfg = Plutonium.configuration.public_send(feature) if Plutonium.configuration.respond_to?(feature)
          path if cfg&.respond_to?(:enabled) && cfg.enabled
        end
      end
    end
  end
end
