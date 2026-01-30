# frozen_string_literal: true

require "rails/generators/base"
require_relative "../lib/plutonium_generators"

module Pu
  module Invites
    class InvitableGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Connect an invitable model to send user invites"

      argument :model, type: :string,
        desc: "The invitable model (e.g., Tenant, TeamMember)"

      class_option :role, type: :string, default: "member",
        desc: "Role to assign to invited users"

      class_option :user_model, type: :string, default: "User",
        desc: "The user model name"

      class_option :membership_model, type: :string,
        desc: "The membership model name (defaults to EntityUser)"

      class_option :dest, type: :string, default: "main_app",
        desc: "Destination package for the interaction"

      class_option :email_templates, type: :boolean, default: true,
        desc: "Generate custom email templates for this invitable"

      def validate_requirements
        errors = []

        unless File.exist?(Rails.root.join(model_file_path))
          errors << "Model file not found: #{model_file_path}"
        end

        unless File.exist?(Rails.root.join(definition_file_path))
          errors << "Definition file not found: #{definition_file_path}"
        end

        unless File.exist?(Rails.root.join(policy_file_path))
          errors << "Policy file not found: #{policy_file_path}"
        end

        if errors.any?
          errors.each { |e| say_status :error, e, :red }
          raise Thor::Error, "Required files missing. Ensure #{model_class} resource exists."
        end
      end

      def create_interaction
        template "invitable/invite_user_interaction.rb",
          interaction_path
      end

      def add_invitable_concern
        inject_into_file model_file_path,
          "include Plutonium::Invites::Concerns::Invitable\n  ",
          before: "# add concerns above."
      end

      def add_definition_action
        inject_into_file definition_file_path,
          "  action :invite_user, interaction: #{model_class}::InviteUserInteraction, category: :secondary\n",
          after: /class #{model_class}Definition < .+\n/
      end

      def add_policy_method
        inject_into_file policy_file_path,
          "def invite_user?\n    record.can_invite_user?\n  end\n\n  ",
          before: "# Core attributes"
      end

      def create_email_templates
        return unless options[:email_templates]

        template "invitable/invitation.html.erb",
          "packages/invites/app/views/invites/user_invite_mailer/invitation_#{model_table}.html.erb"

        template "invitable/invitation.text.erb",
          "packages/invites/app/views/invites/user_invite_mailer/invitation_#{model_table}.text.erb"
      end

      def show_instructions
        say "\n"
        say "Connected #{model_class} as invitable!", :green
        say "\n"
        say "Implement #{model_class}#on_invite_accepted(user) to handle post-acceptance logic."
        say "\n"
      end

      private

      def model_class
        model.camelize
      end

      def model_table
        model.underscore
      end

      def user_model
        options[:user_model].camelize
      end

      def user_table
        options[:user_model].underscore
      end

      def model_file_path
        "app/models/#{model_table}.rb"
      end

      def definition_file_path
        "app/definitions/#{model_table}_definition.rb"
      end

      def policy_file_path
        "app/policies/#{model_table}_policy.rb"
      end

      def role
        options[:role]
      end

      def membership_model
        options[:membership_model] || "EntityUser"
      end

      def interaction_path
        dest = options[:dest]&.underscore
        if dest == "main_app"
          "app/interactions/#{model_table}/invite_user_interaction.rb"
        else
          "packages/#{dest}/app/interactions/#{dest}/#{model_table}/invite_user_interaction.rb"
        end
      end
    end
  end
end
