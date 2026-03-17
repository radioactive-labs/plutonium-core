# frozen_string_literal: true

require "rails/generators/base"
require_relative "../lib/plutonium_generators"

module Pu
  module Saas
    class WelcomeGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::RodauthRedirects

      source_root File.expand_path("welcome/templates", __dir__)

      desc "Generate a post-login welcome flow with onboarding and entity selection"

      class_option :user_model, type: :string, required: true,
        desc: "The user model name (e.g., User)"

      class_option :entity_model, type: :string, required: true,
        desc: "The entity model name (e.g., Organization)"

      class_option :portal, type: :string, required: true,
        desc: "The portal engine name (e.g., CustomerPortal)"

      class_option :membership_model, type: :string,
        desc: "The membership model name (defaults to <Entity><User>)"

      class_option :rodauth, type: :string, default: "user",
        desc: "Rodauth configuration name"

      class_option :profile, type: :boolean, default: false,
        desc: "Include profile setup in onboarding"

      def validate_requirements
        errors = []

        unless File.exist?(user_model_path)
          errors << "User model not found: #{user_model_path.relative_path_from(Rails.root)}"
        end

        unless File.exist?(entity_model_path)
          errors << "Entity model not found: #{entity_model_path.relative_path_from(Rails.root)}"
        end

        if File.exist?(user_model_path)
          user_content = File.read(user_model_path)
          unless user_content.include?("has_many :#{entity_table.pluralize}")
            errors << "User model missing 'has_many :#{entity_table.pluralize}' — run the membership generator first"
          end
        end

        if errors.any?
          errors.each { |e| say_status :error, e, :red }
          raise Thor::Error, "Required files missing:\n  - #{errors.join("\n  - ")}"
        end
      end

      def create_authenticated_controller
        template "app/controllers/authenticated_controller.rb",
          "app/controllers/authenticated_controller.rb"
      end

      def create_welcome_controller
        template "app/controllers/welcome_controller.rb",
          "app/controllers/welcome_controller.rb"
      end

      def create_views
        template "app/views/layouts/welcome.html.erb",
          "app/views/layouts/welcome.html.erb"

        template "app/views/welcome/select_entity.html.erb",
          "app/views/welcome/select_entity.html.erb"

        template "app/views/welcome/onboarding.html.erb",
          "app/views/welcome/onboarding.html.erb"
      end

      def add_routes
        routes_file = "config/routes.rb"
        routes_content = File.read(Rails.root.join(routes_file))

        if routes_content.include?("# Welcome & onboarding")
          say_status :skip, "Welcome routes already present", :yellow
          return
        end

        route_code = <<-RUBY

  # Welcome & onboarding
  get "welcome", to: "welcome#index"
  get "welcome/onboard", to: "welcome#new_entity", as: :welcome_onboard
  post "welcome/onboard", to: "welcome#onboard"
        RUBY

        # Remove the standalone invites welcome route if it exists,
        # since the main WelcomeController now handles /welcome
        if routes_content.include?('get "welcome", to: "invites/welcome#index"')
          gsub_file routes_file,
            /\n\s*# Welcome route \(handled by invites.*\n\s*get "welcome", to: "invites\/welcome#index"\n/,
            "\n"
        end

        inject_into_file routes_file,
          route_code,
          before: /^end\s*\z/
      end

      def configure_rodauth
        return unless rodauth?

        update_rodauth_redirects("app/rodauth/#{rodauth_config}_rodauth_plugin.rb")
      end

      def show_instructions
        say "\n"
        say "=" * 79
        say "\n"
        say "Welcome flow installed successfully!"
        say "\n"
        say "Next steps:"
        say "\n"
        say "1. Run migrations (if you haven't already):"
        say "   rails db:migrate"
        say "\n"
        say "2. Customize the onboarding view to match your app:"
        say "   app/views/welcome/onboarding.html.erb"
        say "\n"
        if profile?
          say "3. Ensure your User model has a `profile` association:"
          say "   has_one :profile"
          say "\n"
        end
        say "=" * 79
        say "\n"
      end

      private

      def user_model
        options[:user_model].camelize
      end

      def user_table
        options[:user_model].underscore
      end

      def entity_model
        options[:entity_model].camelize
      end

      def entity_table
        options[:entity_model].underscore
      end

      def portal_engine
        options[:portal].camelize
      end

      def membership_model
        options[:membership_model] || "#{entity_model}#{user_model}"
      end

      def rodauth_config
        options[:rodauth]
      end

      def rodauth?
        rodauth_config.present?
      end

      def profile?
        options[:profile]
      end

      def entity_model_path
        Rails.root.join("app/models/#{entity_table}.rb")
      end

      def user_model_path
        Rails.root.join("app/models/#{user_table}.rb")
      end
    end
  end
end
