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

      def start
        create_portal
        connect_entity_to_portal
        customize_entity_policy
        add_entity_url_helper
        add_entity_link_to_header
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def create_portal
        generate "pu:pkg:portal", "#{options[:portal_name]} --auth=#{rodauth_config} --scope=#{entity_model}"
      end

      def connect_entity_to_portal
        # Shell out so the subprocess can load the newly created entity model
        generate "pu:res:conn", "#{entity_model} --dest=#{portal_package} --singular --policy"
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
        methods = <<-RUBY
      # Returns the URL to the current entity's show page.
      def entity_url
        resource_url_for(current_scoped_entity)
      end

      # Returns all entities the current user belongs to (for the entity switcher).
      def user_entities
        @user_entities ||= current_user.#{entity_table.pluralize}
      end
        RUBY
        inject_into_concerns_controller concerns_controller_path,
          helper_methods: [:entity_url, :user_entities],
          methods: methods
      end

      def add_entity_link_to_header
        header_path = resource_header_path
        return unless File.exist?(Rails.root.join(header_path))

        file_content = File.read(Rails.root.join(header_path))
        return if file_content.include?("entity_url")

        inject_into_file header_path,
          "          section.with_link(label: current_scoped_entity.name, href: entity_url)\n",
          before: /\s*section\.with_link\(label: "Profile"/
      end

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

      def resource_header_path
        "packages/#{portal_package}/app/views/plutonium/_resource_header.html.erb"
      end
    end
  end
end
