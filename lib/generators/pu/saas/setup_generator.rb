# frozen_string_literal: true

require "rails/generators/base"
require_relative "../lib/plutonium_generators"

module Pu
  module Saas
    class SetupGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Generate a complete SaaS setup with user, entity, and membership"

      class_option :user, type: :string, required: true,
        desc: "The user model name (e.g., Customer)"

      class_option :entity, type: :string, required: true,
        desc: "The entity model name (e.g., Organization)"

      class_option :allow_signup, type: :boolean, default: true,
        desc: "Whether to allow users to sign up to the platform"

      class_option :roles, type: :array, default: %w[member owner],
        desc: "Available roles for memberships"

      class_option :skip_entity, type: :boolean, default: false,
        desc: "Skip entity model generation"

      class_option :skip_membership, type: :boolean, default: false,
        desc: "Skip membership model generation"

      class_option :user_attributes, type: :array, default: [],
        desc: "Additional attributes for the user model (e.g., name:string)"

      class_option :entity_attributes, type: :array, default: [],
        desc: "Additional attributes for the entity model"

      class_option :membership_attributes, type: :array, default: [],
        desc: "Additional attributes for the membership model"

      class_option :api_client, type: :string, default: nil,
        desc: "Generate an API client model (e.g., ApiClient)"

      class_option :api_client_roles, type: :array, default: %w[read_only write admin],
        desc: "Available roles for API client memberships"

      def start
        ensure_rodauth_installed
        generate_user
        generate_entity unless options[:skip_entity]
        generate_membership unless options[:skip_membership]
        generate_api_client if options[:api_client].present?
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def ensure_rodauth_installed
        return if File.exist?(Rails.root.join("app/rodauth/rodauth_app.rb"))

        invoke "pu:rodauth:install"
      end

      def generate_user
        # Use class-based invocation to avoid Thor's invoke caching
        klass = Rails::Generators.find_by_namespace("pu:saas:user")
        klass.new(
          [options[:user]],
          {
            allow_signup: options[:allow_signup],
            extra_attributes: options[:user_attributes],
            force: options[:force],
            skip: options[:skip]
          }
        ).invoke_all
      end

      def generate_entity
        # Use class-based invocation to avoid Thor's invoke caching
        klass = Rails::Generators.find_by_namespace("pu:saas:entity")
        klass.new(
          [options[:entity]],
          {
            extra_attributes: options[:entity_attributes],
            dest: options[:dest],
            force: options[:force],
            skip: options[:skip]
          }
        ).invoke_all
      end

      def generate_membership
        # Use class-based invocation to avoid Thor's invoke caching
        klass = Rails::Generators.find_by_namespace("pu:saas:membership")
        klass.new(
          [],
          {
            user: options[:user],
            entity: options[:entity],
            roles: options[:roles],
            extra_attributes: options[:membership_attributes],
            dest: options[:dest],
            force: options[:force],
            skip: options[:skip]
          }
        ).invoke_all
      end

      def generate_api_client
        # Use class-based invocation to avoid Thor's invoke caching
        klass = Rails::Generators.find_by_namespace("pu:saas:api_client")
        api_client_options = {
          roles: options[:api_client_roles],
          dest: options[:dest],
          force: options[:force],
          skip: options[:skip]
        }

        # Scope to entity if entity is being generated
        api_client_options[:entity] = options[:entity] unless options[:skip_entity]

        klass.new([options[:api_client]], api_client_options).invoke_all
      end
    end
  end
end
