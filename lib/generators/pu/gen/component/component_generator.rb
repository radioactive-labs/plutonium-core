# frozen_string_literal: true

return unless PlutoniumGenerators.cli?

module Pu
  module Gen
    class ComponentGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Create a view component"

      argument :name

      def normalize_name
        @name = name.camelize.gsub(/Component$/, "")
      end

      def start
        template "component.rb", "#{component_path}.rb"
        template "component.html.erb", "#{component_path}.html.erb"
        template "controller.js", controller_path

        controllers_index_file = File.join __dir__, "../../../../../app/assets/javascripts/controllers/index.js"
        insert_into_file controllers_index_file, controller_import, after: /.*Import controllers here*\n/
        insert_into_file controllers_index_file, controller_registration, after: /.*Register controllers here*\n/
        insert_into_file controllers_index_file, controller_export, after: /.*Export controllers here*\n/
      end

      protected

      def dest_dir
        "app/views/components/"
      end

      def component_name
        name.demodulize
      end

      def component_classname
        "#{component_name}Component"
      end

      def component_module
        name.deconstantize.presence
      end

      def component_namespace
        ["PlutoniumUi", component_module].compact.join "::"
      end

      def component_reference
        [component_namespace, component_classname].compact.join "::"
      end

      def component_dir
        [component_module, component_name.underscore].compact.join("::").underscore
      end

      def component_base_path
        File.join dest_dir, component_dir, component_name.underscore
      end

      def component_path
        "#{component_base_path}_component"
      end

      def component_identifier
        [component_module, component_name].compact.join("::").gsub("::", "__").underscore
      end

      def controller_path
        "#{component_base_path}_controller.js"
      end

      def controller_identifier
        component_identifier.dasherize
      end

      def controller_reference
        [component_module, "#{component_name}Controller"].compact.join("::").gsub("::", "_")
      end

      def controller_import
        "import #{controller_reference} from \"../../../../#{controller_path}\"\n"
      end

      def controller_registration
        "  application.register(\"#{controller_identifier}\", #{controller_reference})\n"
      end

      def controller_export
        "export { #{controller_reference} }\n"
      end
    end
  end
end
