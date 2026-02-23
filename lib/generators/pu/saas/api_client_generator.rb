# frozen_string_literal: true

require "rails/generators/named_base"
require_relative "../lib/plutonium_generators"

module Pu
  module Saas
    class ApiClientGenerator < ::Rails::Generators::NamedBase
      include PlutoniumGenerators::Generator

      source_root File.expand_path("api_client/templates", __dir__)

      desc "Generate an API client account with optional entity scoping"

      class_option :entity, type: :string,
        desc: "Entity model to scope API clients to (e.g., Organization)"

      class_option :roles, type: :array, default: %w[read_only write admin],
        desc: "Available roles for API client memberships"

      class_option :extra_attributes, type: :array, default: [],
        desc: "Additional attributes for the API client model"

      def start
        generate_api_client_account
        configure_api_client_account
        generate_membership if entity?
        create_interactions
        create_rake_task
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def generate_api_client_account
        invoke "pu:rodauth:account", [name],
          defaults: false,
          mails: false,
          login_column: "login",
          **api_features,
          extra_attributes: options[:extra_attributes],
          force: options[:force],
          skip: options[:skip]
      end

      def configure_api_client_account
        plugin_file = "app/rodauth/#{normalized_name}_rodauth_plugin.rb"

        # Block web signup - internal_request only
        insert_into_file plugin_file, indent(<<~RUBY, 4), after: /# ==> Hooks\n/

          # API clients can only be created programmatically
          before_create_account_route do
            request.halt unless internal_request?
          end

        RUBY

        # Use login instead of email
        insert_into_file plugin_file, indent(<<~RUBY, 4), after: /# ==> General\n/
          # Use login field for application name (not email)
          login_column :login
          login_label "Application Name"
          require_login_confirmation? false
          login_confirm_label nil

          # Don't require email format for login
          require_email_address_logins? false

        RUBY
      end

      def generate_membership
        invoke "pu:res:model", [membership_model_name, *membership_attributes],
          dest: selected_destination_feature,
          force: options[:force],
          skip: options[:skip]

        add_unique_index_to_migration
        add_default_to_role_column
        add_role_enum_to_model
        add_unique_validation_to_model
        add_associations_to_models
      end

      def create_interactions
        template "app/interactions/create_interaction.rb.tt",
          "app/interactions/#{normalized_name}/create_interaction.rb"

        template "app/interactions/disable_interaction.rb.tt",
          "app/interactions/#{normalized_name}/disable_interaction.rb"

        inject_definition_actions
        inject_policy_methods
      end

      def create_rake_task
        template "lib/tasks/api_client.rake.tt",
          "lib/tasks/#{normalized_name}.rake"
      end

      def inject_definition_actions
        definition_file = "app/definitions/#{normalized_name}_definition.rb"

        inject_into_file definition_file, indent(<<~RUBY, 2), after: /class #{name.classify}Definition < .+\n/
          action :register, interaction: #{name.classify}::CreateInteraction, collection: true, category: :primary
          action :disable, interaction: #{name.classify}::DisableInteraction, category: :danger

        RUBY
      end

      def inject_policy_methods
        policy_file = "app/policies/#{normalized_name}_policy.rb"

        # Uncomment and modify create? to return false (update? inherits from create?)
        gsub_file policy_file,
          /  # def create\?\n  #   true\n  # end/,
          <<~RUBY.chomp
            def create?
              false
            end

            def register?
              true
            end
          RUBY

        # Add disable? method
        inject_into_file policy_file, <<~RUBY, before: /^\s*# Core attributes/
          def disable?
            # Can only disable verified (active) accounts
            record.status == "verified"
          end

        RUBY
      end

      # Membership helpers (similar to pu:saas:membership but simpler)

      def add_unique_index_to_migration
        migration_file = find_migration_file
        return unless migration_file

        insert_into_file migration_file,
          indent("add_index :#{membership_table_name}, [:#{normalized_entity_name}_id, :#{normalized_name}_id], unique: true\n", 4),
          before: /^  end\s*$/
      end

      def add_default_to_role_column
        migration_file = find_migration_file
        return unless migration_file

        gsub_file migration_file,
          /t\.integer :role, null: false/,
          "t.integer :role, null: false, default: 0"
      end

      def add_role_enum_to_model
        model_file = File.join("app", "models", "#{membership_model_name}.rb")
        return unless File.exist?(Rails.root.join(model_file))

        inject_into_file model_file,
          indent("enum :role, {#{roles_enum}}\n", 2),
          before: /^\s*# add enums above\./
      end

      def add_unique_validation_to_model
        model_file = File.join("app", "models", "#{membership_model_name}.rb")
        return unless File.exist?(Rails.root.join(model_file))

        validation = "validates :#{normalized_name}, uniqueness: {scope: :#{normalized_entity_name}_id, message: \"is already registered for this #{normalized_entity_name.humanize.downcase}\"}\n"
        inject_into_file model_file, indent(validation, 2), before: /^\s*# add validations above\./
      end

      def add_associations_to_models
        # Add to entity model
        entity_model_path = File.join("app", "models", "#{normalized_entity_name}.rb")
        if File.exist?(Rails.root.join(entity_model_path))
          associations = <<~RUBY
            has_many :#{membership_table_name}, dependent: :destroy
            has_many :#{normalized_name.pluralize}, through: :#{membership_table_name}
          RUBY
          inject_into_file entity_model_path, indent(associations, 2), before: /^\s*# add has_many associations above\.\n/
        end

        # Add to API client model
        api_client_model_path = File.join("app", "models", "#{normalized_name}.rb")
        if File.exist?(Rails.root.join(api_client_model_path))
          associations = <<~RUBY
            has_many :#{membership_table_name}, dependent: :destroy
            has_many :#{normalized_entity_name.pluralize}, through: :#{membership_table_name}
          RUBY
          inject_into_file api_client_model_path, indent(associations, 2), before: /^\s*# add has_many associations above\.\n/
        end
      end

      def find_migration_file
        Dir[Rails.root.join("db", "migrate", "*_create_#{membership_table_name}.rb")].first
      end

      # Feature configuration

      def api_features
        {
          base: true,
          create_account: true,
          internal_request: true,
          http_basic_auth: true,
          close_account: true,
          case_insensitive_login: true
        }
      end

      # Naming helpers

      def normalized_name = name.underscore

      def display_name = name.underscore.humanize.downcase

      def entity? = options[:entity].present?

      def normalized_entity_name = options[:entity]&.underscore

      def membership_model_name = "#{normalized_entity_name}_#{normalized_name}"

      def membership_table_name = membership_model_name.pluralize

      def membership_attributes
        [
          "#{normalized_entity_name}:references",
          "#{normalized_name}:references",
          "role:integer"
        ]
      end

      def roles
        Array(options[:roles]).flat_map { |r| r.split(",") }.map(&:strip)
      end

      def roles_enum
        roles.each_with_index.map { |r, i| "#{r}: #{i}" }.join(", ")
      end

      def default_role = roles.first

      def selected_destination_feature
        feature_option :dest, prompt: "Select destination feature"
      end
    end
  end
end
