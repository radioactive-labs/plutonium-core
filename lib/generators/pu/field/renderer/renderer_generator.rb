# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Field
    class RendererGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Generates a field renderer"

      argument :name

      def start
        in_root do
          template "renderer.rb", "app/plutonium/fields/renderers/#{name.underscore}_renderer.rb"
          insert_into_file "config/initializers/plutonium.rb", registration_statement, after: /.*# Register components here.*\n/
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def registration_statement
        indent "Plutonium::Core::Fields::Renderers::Factory.map_type :#{name.underscore}, to: Fields::Renderers::#{name.camelize}Renderer\n", 2
      end
    end
  end
end
