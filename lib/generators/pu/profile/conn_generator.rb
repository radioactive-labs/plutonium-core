# frozen_string_literal: true

require "rails/generators/base"
require_relative "../lib/plutonium_generators"

module Pu
  module Profile
    class ConnGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Connect a Profile resource to a portal and configure the profile_url helper"

      argument :name, type: :string, required: false, banner: "RESOURCE"

      class_option :dest, type: :string,
        desc: "Destination portal"

      class_option :user_model, type: :string, default: "User",
        desc: "The Rodauth user model"

      def start
        validate_portal_destination!
        connect_to_portal
        customize_policy
        customize_definition
        customize_controller
        add_profile_url_helper
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def validate_portal_destination!
        if selected_destination_portal == "main_app"
          raise ArgumentError, <<~MSG.squish
            pu:profile:conn is for portal packages only. For main_app, configure
            profile_url directly in your ResourceController.
          MSG
        end
      end

      def connect_to_portal
        invoke "pu:res:conn", [resource_class_name],
          dest: selected_destination_portal,
          singular: true,
          policy: true,
          definition: true,
          force: options[:force],
          skip: options[:skip]
      end

      def customize_policy
        content = <<-RUBY.chomp

  # Profile is scoped to current user, not entity.
  # Note: `user` here is the policy's user method (current authenticated user),
  # while `#{user_table}` is the model's association name.
  relation_scope do |relation|
    skip_default_relation_scope!
    relation.where(#{user_table}: user)
  end

  def create?
    user.#{profile_association}.nil?
  end

  def destroy?
    false
  end

  # User is set automatically from current_user, not via mass assignment
  def permitted_attributes_for_create
    super - [:#{user_table}]
  end
        RUBY
        inject_into_file policy_path, content, after: /include #{dest_name.camelize}::ResourcePolicy\n/
      end

      def customize_definition
        # Add ShowPage with SecuritySection
        content = indent(<<~RUBY, 2)

          class ShowPage < ShowPage
            private

            def render_after_content
              render Plutonium::Profile::SecuritySection.new
            end
          end
        RUBY
        inject_into_file definition_path, content, after: /include #{dest_name.camelize}::ResourceDefinition\n/
      end

      def customize_controller
        # Set user automatically when creating profile
        content = <<-RUBY.chomp

  private

  def resource_params
    super.merge(#{user_table}: current_user)
  end
        RUBY
        inject_into_file controller_path, content, after: /include #{dest_name.camelize}::Concerns::Controller\n/
      end

      def add_profile_url_helper
        content = <<-RUBY.chomp

      included do
        helper_method :profile_url
      end

      private

      # Returns the URL to the user's profile page.
      def profile_url
        profile = current_user.#{profile_association}
        if profile
          resource_url_for(profile)
        else
          resource_url_for(#{resource_class_name}, action: :new)
        end
      end
        RUBY
        inject_into_file concerns_controller_path, content, after: /# add concerns above\.\n/
      end

      def profile_association
        # The install generator always exposes the profile as `:profile` on the
        # user model (via class_name:), regardless of the underlying class name.
        "profile"
      end

      def resource_class_name
        (name.presence || "#{options[:user_model]}Profile").camelize
      end

      def user_table
        options[:user_model].underscore
      end

      def dest_name
        selected_destination_portal
      end

      def concerns_controller_path
        "packages/#{dest_name}/app/controllers/#{dest_name}/concerns/controller.rb"
      end

      def controller_path
        "packages/#{dest_name}/app/controllers/#{dest_name}/#{resource_class_name.underscore.pluralize}_controller.rb"
      end

      def policy_path
        "packages/#{dest_name}/app/policies/#{dest_name}/#{resource_class_name.underscore}_policy.rb"
      end

      def definition_path
        "packages/#{dest_name}/app/definitions/#{dest_name}/#{resource_class_name.underscore}_definition.rb"
      end

      def selected_destination_portal
        @selected_destination_portal ||= portal_option :dest, prompt: "Select destination portal"
      end
    end
  end
end
