# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Test
    class ScaffoldGenerator < Rails::Generators::NamedBase
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Scaffold Plutonium::Testing tests for a resource across one or more portals"

      class_option :portals, type: :array, required: true,
        desc: "Portals to scaffold tests for (e.g. admin,org)"
      class_option :concerns, type: :array, default: %w[crud policy definition],
        desc: "Concerns to include (crud,policy,definition,nested,model,interaction)"
      class_option :parent, type: :string, desc: "Parent association for nested resources"
      class_option :dest, type: :string, default: "main_app",
        desc: "main_app or package name"

      def scaffold
        options[:portals].each { |portal| scaffold_for_portal(portal) }
      end

      private

      CONCERN_MAP = {
        "crud" => "ResourceCrud",
        "policy" => "ResourcePolicy",
        "definition" => "ResourceDefinition",
        "model" => "ResourceModel",
        "interaction" => "ResourceInteraction",
        "nested" => "NestedResource",
        "portal_access" => "PortalAccess"
      }.freeze

      def concern_module_name(concern)
        CONCERN_MAP.fetch(concern) { concern.camelize }
      end

      def scaffold_for_portal(portal)
        @portal = portal
        @resource_class = name
        @file_name = name.underscore.tr("/", "_")
        @class_name = "#{portal.camelize}Portal::#{name.tr("::", "")}Test"
        @concerns = options[:concerns]
        @parent = options[:parent]
        target_dir = (options[:dest] == "main_app") ? "test/integration" : "packages/#{options[:dest]}/test/integration"
        target = "#{target_dir}/#{portal}_portal/#{@file_name}_test.rb"
        template "integration_test.rb.tt", target
      end
    end
  end
end
