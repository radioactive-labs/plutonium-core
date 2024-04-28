# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Pkg
    class FeatureGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Create a plutonium feature package"

      argument :name

      def start
        validate_package_name package_name

        template "lib/engine.rb", "packages/#{package_namespace}/lib/engine.rb"

        %w[controllers interactions models policies presenters query_objects].each do |dir|
          directory "app/#{dir}", "packages/#{package_namespace}/app/#{dir}/#{package_namespace}"
        end
        create_file "packages/#{package_namespace}/app/views/#{package_namespace}/.keep"
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def package_name
        name.camelize
      end

      def package_namespace
        package_name.underscore
      end

      def package_type
        "Pkg::Feature"
      end
    end
  end
end
