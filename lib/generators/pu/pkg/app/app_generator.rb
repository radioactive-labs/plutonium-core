# frozen_string_literal: true

require "plutonium_generators"

module Pu
  module Pkg
    class AppGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Create a plutonium app package"

      argument :name

      def start
        validate_package_name package_name

        if defined?(RodauthApp) && (rodauths = RodauthApp.opts[:rodauths].keys).present?
          rodauth_account = prompt.select("Select rodauth account to authenticate with:", rodauths + [:none])
          @rodauth_account = rodauth_account unless rodauth_account == :none
        elsif prompt.yes?("Do you want to grant public access?")
          @public_access = true
        else
          @bring_your_own_auth = true
        end

        template "lib/engine.rb", "packages/#{package_namespace}/lib/engine.rb"
        template "config/routes.rb", "packages/#{package_namespace}/config/routes.rb"

        %w[controllers policies presenters].each do |dir|
          directory "app/#{dir}", "packages/#{package_namespace}/app/#{dir}/#{package_namespace}"
        end
        create_file "packages/#{package_namespace}/app/views/#{package_namespace}/.keep"
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      attr_reader :rodauth_account

      def package_name
        name.classify + "App"
      end

      def package_namespace
        package_name.underscore
      end

      def package_type
        "Packaging::App"
      end

      def public_access? = @public_access

      def bring_your_own_auth? = @bring_your_own_auth
    end
  end
end
