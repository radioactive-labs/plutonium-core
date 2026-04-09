# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class ActiveShrineGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set up active_shrine for file uploads"

      class_option :s3, type: :boolean, default: false,
        desc: "Configure S3 storage (adds aws-sdk-s3 gem)"
      class_option :store_dimensions, type: :boolean, default: false,
        desc: "Enable image dimension storage (adds fastimage gem)"

      def start
        bundle "active_shrine"
        bundle "aws-sdk-s3" if options[:s3]
        bundle "fastimage" if options[:store_dimensions]

        generate "active_shrine:install"
        template "config/initializers/shrine.rb", force: true

        disable_active_storage_railtie
        include_active_shrine_model_in_application_record
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      # Active Storage and active_shrine both define `has_one_attached`. Active
      # Storage is loaded by `require "rails/all"`, so it wins by default and
      # `has_one_attached :foo` quietly creates Active Storage attachments
      # (which fail at runtime because the table doesn't exist). Replace
      # `rails/all` with explicit framework requires that exclude
      # active_storage/engine.
      def disable_active_storage_railtie
        return unless File.exist?("config/application.rb")
        unless File.read("config/application.rb").include?(%(require "rails/all"))
          say_status :warn,
            "config/application.rb does not use `require \"rails/all\"`; skipping Active Storage railtie removal. " \
            "Ensure active_storage/engine is NOT required, or `has_one_attached` will resolve to Active Storage instead of active_shrine.",
            :yellow
          return
        end

        gsub_file "config/application.rb",
          /^require "rails\/all"$/,
          <<~RUBY.strip
            require "rails"
            # Active Storage is intentionally excluded — file uploads use active_shrine.
            %w[
              active_record/railtie
              active_model/railtie
              active_job/railtie
              action_controller/railtie
              action_view/railtie
              action_mailer/railtie
              action_cable/engine
              rails/test_unit/railtie
            ].each { |railtie| require railtie }
          RUBY

        # Strip per-environment active_storage.service config since the railtie
        # is gone.
        Dir.glob("config/environments/*.rb").each do |env_file|
          gsub_file env_file,
            /^\s*config\.active_storage\.service\s*=.*\n/,
            ""
        end
      end

      # Include ActiveShrine::Model on ApplicationRecord so the gem's
      # `has_one_attached` / `has_many_attached` macros are available everywhere.
      def include_active_shrine_model_in_application_record
        return unless File.exist?("app/models/application_record.rb")
        return if File.read("app/models/application_record.rb").include?("ActiveShrine::Model")

        inject_into_class "app/models/application_record.rb", "ApplicationRecord", "  include ActiveShrine::Model\n"
      end
    end
  end
end
