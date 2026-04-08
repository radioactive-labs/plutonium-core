# frozen_string_literal: true

require "rails/generators/base"
require_relative "../lib/plutonium_generators"
require_relative "concerns/profile_arguments"

module Pu
  module Profile
    class InstallGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include Concerns::ProfileArguments

      desc "Generate a Profile resource for managing Rodauth account settings"

      class_option :user_model, type: :string, default: "User",
        desc: "The Rodauth user model"

      class_option :dest, type: :string,
        desc: "Package where the Profile resource should be created"

      def start
        normalize_arguments
        generate_profile_scaffold
        add_user_association
        add_unique_index_to_migration
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def generate_profile_scaffold
        invoke "pu:res:scaffold", [@profile_name, *scaffold_attributes],
          dest: selected_destination_feature,
          force: options[:force],
          skip: options[:skip]
      end

      def add_user_association
        # Always expose the association as `:profile` on the user model so that
        # `current_user.profile` works regardless of the underlying class name
        # (e.g. UserProfile, StaffUserProfile, AccountSettings).
        association = if dest_package?
          "  has_one :profile, class_name: \"#{namespaced_class_name}\", dependent: :destroy\n"
        else
          "  has_one :profile, class_name: \"#{class_name}\", dependent: :destroy\n"
        end
        inject_into_file user_model_path, association,
          before: /^\s*# add has_one associations above\.\n/
      end

      def add_unique_index_to_migration
        migration_file = Dir[File.join(migration_dir, "*_create_#{table_name}.rb")].first
        unless migration_file
          say_status :warning, "Migration file not found in #{migration_dir}, skipping unique index", :yellow
          return
        end

        # Add unique: true to the user reference for has_one relationship
        gsub_file migration_file,
          /t\.belongs_to :#{user_table}, null: false, foreign_key: true/,
          "t.belongs_to :#{user_table}, null: false, foreign_key: true, index: {unique: true}"
      end

      def class_name
        @profile_name.camelize
      end

      def namespaced_class_name
        if dest_package?
          "#{dest_name.camelize}::#{class_name}"
        else
          class_name
        end
      end

      def file_name
        @profile_name.underscore
      end

      def user_table
        options[:user_model].underscore
      end

      def user_model_path
        "app/models/#{user_table}.rb"
      end

      def dest_package?
        selected_destination_feature != "main_app"
      end

      def dest_name
        selected_destination_feature
      end

      def migration_dir
        if dest_package?
          "packages/#{dest_name}/db/migrate"
        else
          "db/migrate"
        end
      end

      def table_name
        if dest_package?
          "#{dest_name}_#{file_name.pluralize}"
        else
          file_name.pluralize
        end
      end

      def scaffold_attributes
        ["#{user_table}:belongs_to", *@profile_attributes.map(&:to_s)]
      end

      def selected_destination_feature
        feature_option :dest, prompt: "Select destination feature"
      end
    end
  end
end
