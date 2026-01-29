# frozen_string_literal: true

return unless defined?(Rodauth::Rails)

require "rails/generators/named_base"
require_relative "../lib/plutonium_generators"

module Pu
  module Rodauth
    class CustomerGenerator < ::Rails::Generators::NamedBase
      include PlutoniumGenerators::Concerns::Logger

      source_root File.expand_path("templates", __dir__)

      desc "Generate a rodauth-rails account optimized for customer-based tasks"

      class_option :allow_signup, type: :boolean, default: true,
        desc: "Whether to allow customer to sign up to the platform"

      class_option :entity, default: "Entity",
        desc: "Generate an entity model for customer accounts. Defaults to 'Entity'",
        aliases: ["--entity", "-e"]

      class_option :extra_attributes, type: :array, default: [],
        desc: "Additional attributes to add to the account model (e.g., name:string)"

      def start
        create_customer_account
        create_entity_model_and_membership
        configure_model_relationships
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def create_customer_account
        invoke "pu:rodauth:account", [name],
          defaults: false,
          **customer_features,
          extra_attributes: Array(options[:extra_attributes]),
          force: options[:force],
          skip: options[:skip],
          lint: true
      end

      def create_entity_model_and_membership
        invoke "pu:res:entity", [normalized_entity_name],
          auth_account: normalized_name,
          force: options[:force],
          skip: options[:skip]
      end

      def configure_model_relationships
        entity_model_path = File.join("app", "models", "#{normalized_entity_name}.rb")
        if File.exist?(entity_model_path)
          insert_into_file entity_model_path, <<~RUBY + "  ", before: /# add has_many associations above\.\n/
            has_many :#{normalized_entity_membership_name.pluralize}
              has_many :#{normalized_name.pluralize}, through: :#{normalized_entity_membership_name.pluralize}
          RUBY
        end

        customer_model_path = File.join("app", "models", "#{normalized_name}.rb")
        if File.exist?(customer_model_path)
          insert_into_file customer_model_path, <<~RUBY + "  ", before: /# add has_many associations above\.\n/
            has_many :#{normalized_entity_membership_name.pluralize}
              has_many :#{normalized_entity_name.pluralize}, through: :#{normalized_entity_membership_name.pluralize}
          RUBY
        end
      end

      private

      def customer_features
        features = %i[
          login
          remember
          logout
          create_account
          verify_account
          verify_account_grace_period
          reset_password
          reset_password_notify
          change_login
          verify_login_change
          change_password
          change_password_notify
          case_insensitive_login
          internal_request
        ]

        features.delete(:create_account) unless options[:allow_signup]
        features.map { |feature| [feature, true] }.to_h
      end

      def normalized_name = name.underscore

      def normalized_entity_name = options[:entity].underscore

      def normalized_entity_membership_name
        "#{normalized_entity_name.underscore}_#{normalized_name}"
      end
    end
  end
end
