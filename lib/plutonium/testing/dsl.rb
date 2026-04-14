# frozen_string_literal: true

module Plutonium
  module Testing
    module DSL
      extend ActiveSupport::Concern

      class PortalNotFound < StandardError; end

      DEFAULT_ACTIONS = %i[index show new create edit update destroy].freeze

      class_methods do
        def resource_tests_for(resource_class, portal:, path_prefix: nil, parent: nil,
          actions: DEFAULT_ACTIONS, skip: [],
          associated_with: nil, sgid_routing: false, has_cents: [])
          @resource_tests_config = {
            resource: resource_class,
            portal: portal,
            path_prefix: path_prefix || resolve_portal_path_prefix(portal),
            parent: parent,
            actions: actions,
            skip: skip,
            associated_with: associated_with,
            sgid_routing: sgid_routing,
            has_cents: has_cents
          }
        end

        def resource_tests_config
          @resource_tests_config or raise "resource_tests_for not called on #{name}"
        end

        private

        def resolve_portal_path_prefix(portal_sym)
          engine_name = "#{portal_sym.to_s.camelize}Portal::Engine"
          engine_const = engine_name.safe_constantize
          unless engine_const
            raise PortalNotFound, "Could not resolve portal :#{portal_sym} (looked for #{engine_name})"
          end

          mount = find_engine_mount(engine_const)
          unless mount
            raise PortalNotFound, "Engine #{engine_const} is not mounted in routes"
          end

          mount.path.spec.to_s.sub(/\(\.:format\)\z/, "").chomp("/")
        end

        def find_engine_mount(engine_const)
          Rails.application.routes.routes.find do |route|
            matches_engine?(route.app, engine_const)
          end
        end

        def matches_engine?(app, engine_const)
          return true if app == engine_const
          return false unless app.respond_to?(:app)
          return false if app.app == app
          matches_engine?(app.app, engine_const)
        end
      end

      def current_portal
        @__portal_override || self.class.resource_tests_config.fetch(:portal)
      end

      def current_path_prefix
        self.class.resource_tests_config.fetch(:path_prefix)
      end
    end
  end
end
