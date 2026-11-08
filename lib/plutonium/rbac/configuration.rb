# frozen_string_literal: true

module Plutonium
  module Rbac
    # Mirrors Plutonium::Wizard::Configuration: `enabled` gates both the
    # subsystem and its migration (see Plutonium::Migrations).
    class Configuration
      # @return [Boolean] whether RBAC (and its migration) is enabled
      attr_accessor :enabled

      def initialize
        @enabled = false
      end
    end
  end
end
