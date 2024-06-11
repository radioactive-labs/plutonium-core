# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Field
    class InputGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Generates a field input"

      argument :name

      def start
        in_root do
          template "input.rb", "app/plutonium/fields/inputs/#{name.underscore}_input.rb"
          insert_into_file "config/initializers/plutonium.rb", registration_statement, after: /.*# Register components here.*\n/
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def registration_statement
        indent "Plutonium::Core::Fields::Inputs::Factory.map_type :#{name.underscore}, to: Fields::Inputs::#{name.camelize}Input\n", 2
      end
    end
  end
end
