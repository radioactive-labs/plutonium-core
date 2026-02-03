# frozen_string_literal: true

return unless defined?(Rodauth::Rails)

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

      def start
        generate_user
        generate_entity unless options[:skip_entity]
        generate_membership unless options[:skip_membership]
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

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
    end
  end
end
