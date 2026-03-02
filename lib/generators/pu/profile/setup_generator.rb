# frozen_string_literal: true

require "rails/generators/base"
require_relative "../lib/plutonium_generators"
require_relative "concerns/profile_arguments"

module Pu
  module Profile
    class SetupGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include Concerns::ProfileArguments

      desc "Generate a complete Profile setup with resource and portal connection"

      class_option :user_model, type: :string, default: "User",
        desc: "The Rodauth user model"

      class_option :dest, type: :string,
        desc: "Package where the Profile resource should be created"

      class_option :portal, type: :string,
        desc: "Portal to connect the Profile to"

      def start
        normalize_arguments
        generate_profile
        connect_to_portal if options[:portal].present?
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def generate_profile
        klass = Rails::Generators.find_by_namespace("pu:profile:install")
        klass.new(
          [@profile_name, *@profile_attributes],
          {
            user_model: options[:user_model],
            dest: selected_destination_feature,
            force: options[:force],
            skip: options[:skip]
          }
        ).invoke_all
      end

      def connect_to_portal
        # Shell out to a new process so the newly created model file gets loaded
        generate "pu:profile:conn", "#{resource_class_name} --dest=#{options[:portal]} --user-model=#{options[:user_model]}"
      end

      def resource_class_name
        if dest_package?
          "#{dest_name.camelize}::#{@profile_name.camelize}"
        else
          @profile_name.camelize
        end
      end

      def dest_package?
        selected_destination_feature != "main_app"
      end

      def dest_name
        selected_destination_feature
      end

      def selected_destination_feature
        @selected_destination_feature ||= feature_option :dest, prompt: "Select destination feature"
      end
    end
  end
end
