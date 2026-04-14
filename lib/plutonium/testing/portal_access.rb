# frozen_string_literal: true

require "plutonium/testing/auth_helpers"

module Plutonium
  module Testing
    module PortalAccess
      extend ActiveSupport::Concern
      include Plutonium::Testing::AuthHelpers

      class_methods do
        attr_reader :portal_access_config

        def portal_access_for(portals:, matrix:)
          @portal_access_config = {portals: portals, matrix: matrix}
          install_portal_access_tests!
        end

        def install_portal_access_tests!
          cfg = portal_access_config
          cfg[:matrix].each do |role_sym, allowed_portals|
            cfg[:portals].each do |portal_sym|
              expected_allow = allowed_portals.include?(portal_sym)
              test "portal access: #{role_sym} -> #{portal_sym} (#{expected_allow ? "allowed" : "blocked"})" do
                login_as_role(role_sym)
                get portal_root_path(portal_sym)
                if expected_allow
                  assert_includes [200, 302], response.status,
                    "Expected #{role_sym} to access #{portal_sym}, got #{response.status}"
                else
                  assert_includes [302, 401, 403, 404], response.status,
                    "Expected #{role_sym} blocked from #{portal_sym}, got #{response.status}"
                end
              end
            end
          end
        end
      end

      def login_as_role(role_sym)
        raise NotImplementedError, "Override #login_as_role(role_sym) to log in the given role"
      end

      def portal_root_path(portal_sym)
        raise NotImplementedError, "Override #portal_root_path(portal_sym) to return the URL"
      end
    end
  end
end
