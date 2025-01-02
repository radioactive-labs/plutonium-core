# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    module PackageSelector
      def self.included(base)
        base.send :class_option, :src, type: :string, desc: "The source package if applicable"
        base.send :class_option, :dest, type: :string, desc: "The destination package if applicable"
      end

      private

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

      def available_portals
        @available_portals ||= ["main_app"] + available_packages.select { |pkg| pkg.ends_with?("_app") || pkg.ends_with?("_portal") }.sort
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

      def select_feature(selected_package = nil, msg: "Select feature")
        select_package(selected_package, msg: msg, pkgs: available_features)
      end

      def feature_option(name, prompt: nil, option_key: nil)
        # Get stored value or command line option
        ivar = :"@#{name}_feature_option"
        return instance_variable_get(ivar) if instance_variable_defined?(ivar)

        # Validate option or prompt user
        option_key ||= name
        value = select_feature(options[option_key], msg: prompt || "Select #{name} feature")
        instance_variable_set(ivar, value)
        value
      end

      def select_portal(selected_package = nil, msg: "Select portal")
        select_package(selected_package, msg: msg, pkgs: available_portals)
      end

      def portal_option(name, prompt: nil, option_key: nil)
        # Get stored value or command line option
        ivar = :"@#{name}_portal_option"
        return instance_variable_get(ivar) if instance_variable_defined?(ivar)

        # Validate option or prompt user
        option_key ||= name
        value = select_portal(options[option_key], msg: prompt || "Select #{name} portal")
        instance_variable_set(ivar, value)
        value
      end
    end
  end
end
