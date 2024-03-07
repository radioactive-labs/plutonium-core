# frozen_string_literal: true

return if PlutoniumGenerators.rails?

module Pu
  module Gen
    class ComponentGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Create a view component"

      argument :name

      def start
        template "component.rb", "app/views/components/#{component_path}.rb"
        template "component.html.erb", "app/views/components/#{component_path}.html.erb"
      end

      protected

      def component_name
        name.classify
      end

      def component_path
        [component_module, component_class, component_class].compact.join("::").underscore
      end

      def component_class
        component_name.demodulize
      end

      def component_module
        component_name.deconstantize.presence
      end

      def component_namespace
        ["Plutonium::UI", component_module].compact.join "::"
      end
    end
  end
end
