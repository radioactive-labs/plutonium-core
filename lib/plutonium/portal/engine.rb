# frozen_string_literal: true

module Plutonium
  module Portal
    module Engine
      extend ActiveSupport::Concern
      include Plutonium::Engine
      include Plutonium::Package::Engine

      included do
        isolate_namespace to_s.deconstantize.constantize
      end

      class_methods do
        # Shell variant for this portal's controllers (:modern / :plain /
        # :classic). When unset it cascades live to the global
        # Plutonium.configuration.shell; a controller's own `shell` overrides
        # this in turn. Set with `shell :plain`, read with `shell`.
        def shell(value = nil)
          @shell = value unless value.nil?
          @shell.nil? ? Plutonium.configuration.shell : @shell
        end
      end
    end
  end
end
