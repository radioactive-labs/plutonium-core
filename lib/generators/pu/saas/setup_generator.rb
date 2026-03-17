# frozen_string_literal: true

require "rails/generators/base"
require_relative "../lib/plutonium_generators"

module Pu
  module Saas
    class SetupGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Generate a complete SaaS setup with user, entity, membership, portal, and welcome flow"

      class_option :user, type: :string, required: true,
        desc: "The user model name (e.g., User)"

      class_option :entity, type: :string, required: true,
        desc: "The entity model name (e.g., Organization)"

      class_option :allow_signup, type: :boolean, default: true,
        desc: "Whether to allow users to sign up to the platform"

      class_option :roles, type: :array, default: %w[admin member],
        desc: "Additional roles for memberships (owner is always included as the first role)"

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

      class_option :portal, type: :boolean, default: true,
        desc: "Generate a portal with entity scoping"

      class_option :portal_name, type: :string, default: "Dashboard",
        desc: "Portal name (e.g., Dashboard generates DashboardPortal)"

      class_option :welcome, type: :boolean, default: true,
        desc: "Generate the welcome/onboarding flow"

      class_option :invites, type: :boolean, default: true,
        desc: "Generate the user invites package"

      class_option :profile, type: :boolean, default: true,
        desc: "Generate user profile resource"

      class_option :api_client, type: :string, default: nil,
        desc: "Generate an API client model (e.g., ApiClient)"

      class_option :api_client_roles, type: :array, default: %w[read_only write admin],
        desc: "Available roles for API client memberships"

      def start
        ensure_rodauth_installed
        generate_user
        generate_entity unless options[:skip_entity]
        generate_membership unless options[:skip_membership]
        generate_portal if options[:portal] && !options[:skip_entity]
        generate_profile if options[:profile]
        generate_welcome if options[:welcome] && !options[:skip_entity] && options[:portal]
        generate_invites if options[:invites] && !options[:skip_entity] && !options[:skip_membership]
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

      def generate_portal
        generate "pu:saas:portal",
          "--entity-model=#{options[:entity]} --user-model=#{options[:user]}" \
          " --portal-name=#{options[:portal_name]}" \
          " --rodauth=#{rodauth_config}"
      end

      def generate_profile
        generate "pu:profile:setup",
          "--user-model=#{options[:user]} --dest=main_app" \
          "#{" --portal=#{portal_package}" if options[:portal]}"
      end

      def generate_welcome
        generate "pu:saas:welcome",
          "--user-model=#{options[:user]} --entity-model=#{options[:entity]}" \
          " --portal=#{portal_engine}" \
          " --rodauth=#{rodauth_config}" \
          "#{" --profile" if options[:profile]}"
      end

      def generate_invites
        generate "pu:invites:install",
          "--entity-model=#{options[:entity]} --user-model=#{options[:user]} --dest=main_app" \
          " --rodauth=#{rodauth_config}"
      end

      def generate_api_client
        klass = Rails::Generators.find_by_namespace("pu:saas:api_client")
        api_client_options = {
          roles: options[:api_client_roles],
          dest: options[:dest],
          force: options[:force],
          skip: options[:skip]
        }

        api_client_options[:entity] = options[:entity] unless options[:skip_entity]

        klass.new([options[:api_client]], api_client_options).invoke_all
      end

      def rodauth_config
        options[:user].underscore
      end

      def portal_package
        "#{options[:portal_name].underscore}_portal"
      end

      def portal_engine
        "#{options[:portal_name].camelize}Portal"
      end
    end
  end
end
