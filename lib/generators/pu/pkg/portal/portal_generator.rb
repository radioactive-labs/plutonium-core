# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Pkg
    class PortalGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Create a plutonium portal package"

      argument :name

      class_option :auth, type: :string, desc: "Rodauth account to authenticate with (e.g., --auth=user)"
      class_option :public, type: :boolean, default: false, desc: "Grant public access (no authentication)"
      class_option :byo, type: :boolean, default: false, desc: "Bring your own authentication"

      def start
        validate_package_name name
        configure_authentication

        template "lib/engine.rb", "packages/#{package_namespace}/lib/engine.rb"
        template "config/routes.rb", "packages/#{package_namespace}/config/routes.rb"

        template "app/controllers/concerns/controller.rb",
          "packages/#{package_namespace}/app/controllers/#{package_namespace}/concerns/controller.rb"
        template "app/controllers/plutonium_controller.rb",
          "packages/#{package_namespace}/app/controllers/#{package_namespace}/plutonium_controller.rb"

        template "app/controllers/dashboard_controller.rb",
          "packages/#{package_namespace}/app/controllers/#{package_namespace}/dashboard_controller.rb"
        copy_file "app/views/package/dashboard/index.html.erb",
          "packages/#{package_namespace}/app/views/#{package_namespace}/dashboard/index.html.erb"

        %w[policies definitions].each do |dir|
          directory "app/#{dir}", "packages/#{package_namespace}/app/#{dir}/#{package_namespace}"
        end
        create_file "packages/#{package_namespace}/app/views/#{package_namespace}/.keep"

        invoke "pu:eject:shell", [], dest: package_namespace,
          force: options[:force],
          skip: options[:skip]
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      attr_reader :rodauth_account

      def configure_authentication
        if options[:auth].present?
          @rodauth_account = options[:auth].to_sym
        elsif options[:public]
          @public_access = true
        elsif options[:byo]
          @bring_your_own_auth = true
        elsif defined?(RodauthApp) && (rodauths = RodauthApp.opts[:rodauths].keys).present?
          rodauth_account = prompt.select("Select rodauth account to authenticate with:", rodauths + [:none])
          @rodauth_account = rodauth_account unless rodauth_account == :none
        elsif prompt.yes?("Do you want to grant public access?")
          @public_access = true
        else
          @bring_your_own_auth = true
        end
      end

      def package_name
        name.camelize + "Portal"
      end

      def package_namespace
        package_name.underscore
      end

      def package_type
        "Portal::Engine"
      end

      def public_access? = @public_access

      def bring_your_own_auth? = @bring_your_own_auth
    end
  end
end
