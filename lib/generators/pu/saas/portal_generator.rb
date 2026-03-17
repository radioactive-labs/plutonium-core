# frozen_string_literal: true

require "rails/generators/base"
require_relative "../lib/plutonium_generators"

module Pu
  module Saas
    class PortalGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Generate a SaaS portal with entity scoping, entity management, and navigation helpers"

      class_option :entity_model, type: :string, required: true,
        desc: "The entity model name (e.g., Organization)"

      class_option :user_model, type: :string, default: "User",
        desc: "The user model name"

      class_option :portal_name, type: :string, default: "Dashboard",
        desc: "Portal name (e.g., Dashboard generates DashboardPortal)"

      class_option :rodauth, type: :string, default: "user",
        desc: "Rodauth configuration name"

      def create_portal
        generate "pu:pkg:portal", "#{options[:portal_name]} --auth=#{rodauth_config} --scope=#{entity_model}"
      end

      def connect_entity_to_portal
        invoke "pu:res:conn", [entity_model],
          dest: portal_package,
          singular: true,
          policy: true,
          force: options[:force],
          skip: options[:skip]
      end

      def customize_entity_policy
        content = <<-RUBY

  def update?
    current_membership&.owner?
  end

  def destroy?
    false
  end

  def permitted_attributes_for_read
    [:name]
  end

  def permitted_attributes_for_update
    [:name]
  end

  def permitted_associations
    []
  end
        RUBY
        inject_into_file entity_policy_path, content, after: /include #{portal_engine}::ResourcePolicy\n/
      end

      def add_entity_url_helper
        content = <<-RUBY

      included do
        helper_method :entity_url, :user_entities
      end

      private

      # Returns the URL to the current entity's show page.
      def entity_url
        resource_url_for(current_scoped_entity)
      end

      # Returns all entities the current user belongs to (for the entity switcher).
      def user_entities
        @user_entities ||= current_user.#{entity_table.pluralize}
      end
        RUBY
        inject_into_file concerns_controller_path, content, after: /# add concerns above\.\n/
      end

      private

      def entity_model
        options[:entity_model].camelize
      end

      def entity_table
        options[:entity_model].underscore
      end

      def rodauth_config
        options[:rodauth]
      end

      def portal_engine
        "#{options[:portal_name].camelize}Portal"
      end

      def portal_package
        portal_engine.underscore
      end

      def concerns_controller_path
        "packages/#{portal_package}/app/controllers/#{portal_package}/concerns/controller.rb"
      end

      def entity_policy_path
        "packages/#{portal_package}/app/policies/#{portal_package}/#{entity_table}_policy.rb"
      end
    end
  end
end
