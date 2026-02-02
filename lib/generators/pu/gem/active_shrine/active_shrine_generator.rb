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
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
