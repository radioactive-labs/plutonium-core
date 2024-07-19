# frozen_string_literal: true

require "semantic_range"
require "tty-prompt"

module PlutoniumGenerators
  module Generator
    include Concerns::Config
    include Concerns::Logger
    include Concerns::Serializer
    include Concerns::Actions

    def self.included(base)
      base.send :class_option, :interactive, type: :boolean, desc: "Show prompts. Default: true"
      base.send :class_option, :bundle, type: :boolean, desc: "Run bundle after setup. Default: true"
      base.send :class_option, :lint, type: :boolean, desc: "Run linter after generation. Default: false"
    end

    protected

    def reserved_packages
      %w[core reactor app main plutonium pluton8 plutonate]
    end

    def validate_package_name(package_name)
      package_name = package_name.underscore
      error("Package name is reserved\n\n#{reserved_packages.join "\n"}") if reserved_packages.include?(package_name)
      error("Package name cannot end in `_app` or `_portal`") if /(_app|_portal)$/i.match?(package_name)
    end

    def available_packages
      @available_packages ||= begin
        packages = Dir["packages/*"].map { |dir| dir.gsub "packages/", "" }
        packages - reserved_packages
      end
    end

    def available_apps
      @available_apps ||= ["main_app"] + available_packages.select { |pkg| pkg.ends_with?("_app") || pkg.ends_with?("_portal") }.sort
    end

    def available_features
      @available_features ||= ["main_app"] + available_packages.select { |pkg| !(pkg.ends_with?("_app") || pkg.ends_with?("_portal")) }.sort
    end

    def select_package(selected_package = nil, msg: "Select package", pkgs: nil)
      pkgs ||= available_packages
      if pkgs.include?(selected_package)
        selected_package
      else
        prompt.select(msg, pkgs)
      end
    end

    def select_app(selected_package = nil, msg: "Select app")
      select_package(selected_package, msg: msg, pkgs: available_apps)
    end

    def select_feature(selected_package = nil, msg: "Select feature")
      select_package(selected_package, msg: msg, pkgs: available_features)
    end

    # ####################

    def prompt
      @prompt ||= TTY::Prompt.new
    end

    # def appname
    #   defined?(Rails.application) ? Rails.application.class.module_parent.name : "PlutoniumGenerators"
    # end

    # def app_name
    #   appname.underscore
    # end

    def pug_installed?(feature, version: nil)
      installed_version = read_config(:installed, feature)
      return false unless installed_version.present?

      version.present? ? SemanticRange.satisfies?(installed_version, ">=#{version}") : true
    end
  end
end
