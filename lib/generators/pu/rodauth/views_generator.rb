return unless defined?(Rodauth::Rails)

require "rails/generators/base"

require "#{__dir__}/concerns/configuration"

module Pu
  module Rodauth
    class ViewsGenerator < ::Rails::Generators::Base
      include Concerns::Configuration

      source_root "#{__dir__}/templates"
      # namespace "rodauth:views"

      desc "Generate views for selected features\n\n" \
           "Supported Features\n" \
           "=========================================\n" \
           "#{VIEW_CONFIG.keys.sort.map(&:to_s).join "\n"}\n\n\n\n"

      argument :plugin_name, type: :string, optional: true,
        desc: "[CONFIG] Name of the configured rodauth app. Leave blank to use the primary account."

      class_option :features, required: true, type: :array,
        desc: "Rodauth features to generate views for (login, create_account, reset_password, verify_account etc.)"

      class_option :all, aliases: "-a", type: :boolean,
        desc: "Generates views for all Rodauth features",
        default: false

      def validate_selected_features
        if selected_features.empty?
          say "No view features specified!", :yellow
          exit(1)
        elsif (selected_features - view_config.keys).any?
          say "No available view template for feature(s): #{(selected_features - view_config.keys).join(", ")}", :red
          exit(1)
        end
      end

      def create_views
        views.each do |view|
          copy_file view_location(view), "app/views/#{directory}/#{view}.html.erb" do |content|
            content = content.gsub("rodauth.", "rodauth(:#{configuration_name}).") if configuration_name
            content = content.gsub("rodauth/", "#{directory}/")
            content
          end
        end
      end

      private

      def features
        options[:features]
      end

      def views
        selected_features.flat_map { |feature| view_config.fetch(feature) }
      end

      def selected_features
        if options[:all]
          view_config.keys
        elsif features
          features.map(&:to_sym)
        else
          rodauth_configuration.features & view_config.keys
        end
      end

      def directory
        if controller.abstract?
          raise Error, "no controller configured for configuration: #{configuration_name.inspect}"
        end

        controller.controller_path
      end

      def controller
        rodauth_configuration.allocate.rails_controller
      end

      def rodauth_configuration
        require "rodauth-rails" # this requires the project to include the package

        ::Rodauth::Rails.app.rodauth!(configuration_name&.to_sym)
      rescue ArgumentError => e
        say "An error occurred generating views for " \
            "#{configuration_name.present? ? "'#{configuration_name}'" : "primary"} account:\n\n#{e}", :red
        exit(1)
      end

      def configuration_name
        plugin_name
      end

      def view_location(view)
        File.join Plutonium.root, "app/views/rodauth/#{view}.html.erb"
      end
    end
  end
end
