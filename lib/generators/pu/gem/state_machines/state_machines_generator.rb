# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class StateMachinesGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Set up state_machines"

      def start
        bundle "state_machines"
        bundle "state_machines-activerecord"
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
