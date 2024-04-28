# frozen_string_literal: true

require "yaml"

module PlutoniumGenerators
  module Concerns
    module Config
      def write_config(scope, **kwargs)
        write_config! config.deep_merge({scope => kwargs})
      end

      def read_config(scope, key, default: nil)
        config.dig(scope, key) || default
      end

      private

      def config
        in_root do
          if File.exist? config_filename
            YAML.load_file(config_filename, permitted_classes: [Regexp, Symbol]) || {}
          else
            {}
          end
        end
      end

      def write_config!(config)
        in_root do
          File.write(config_filename, YAML.dump(config))
        end
      end

      def config_filename
        ".pu"
      end
    end
  end
end
