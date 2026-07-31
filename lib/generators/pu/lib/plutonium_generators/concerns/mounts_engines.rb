# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    module MountsEngines
      private

      def mount_engine(engine_mount, route_file: "config/routes.rb", authenticated: false)
        return if file_includes?(route_file, engine_mount)

        if authenticated
          mount_authenticated_engine(engine_mount, route_file)
        else
          insert_into_file route_file, before: /^end\s*\z/ do
            "  #{engine_mount}\n"
          end
        end
      end

      def mount_authenticated_engine(engine_mount, route_file)
        ensure_management_constraint

        content = File.read(File.expand_path(route_file, destination_root))
        # Match constraint block opening - use [ \t]* instead of \s* to avoid matching newlines
        constraint_match = content.match(/^(\s*)constraints ManagementConstraint do[ \t]*\n/)

        if constraint_match
          indent = constraint_match[1]
          # Insert after the opening line (not including any subsequent blank lines)
          insert_into_file route_file, after: /^#{Regexp.escape(indent)}constraints ManagementConstraint do[ \t]*\n/ do
            "#{indent}  #{engine_mount}\n"
          end
        else
          # Create new constraint block before the final end
          insert_into_file route_file, before: /^end\s*\z/ do
            "  constraints ManagementConstraint do\n    #{engine_mount}\n  end\n"
          end
        end
      end

      def ensure_management_constraint
        constraint_file = "app/constraints/management_constraint.rb"
        return if File.exist?(File.expand_path(constraint_file, destination_root))

        create_file constraint_file, management_constraint_source
      end

      # Prefer the Rodauth constraint when the app has an admin account to point
      # at — `Rodauth::Rails.authenticate` redirects unauthenticated requests to
      # the login page instead of 404ing on the mount.
      def management_constraint_source
        account = rodauth_management_account
        return management_constraint_stub unless account

        <<~RUBY
          # frozen_string_literal: true

          # Gates the management engines mounted in config/routes.rb.
          class ManagementConstraint
            AUTHENTICATE = Rodauth::Rails.authenticate(#{account})

            def self.matches?(request)
              AUTHENTICATE.call(request)
            end
          end
        RUBY
      end

      def management_constraint_stub
        <<~RUBY
          # frozen_string_literal: true

          # Gates the management engines mounted in config/routes.rb.
          class ManagementConstraint
            # Rodauth (redirects to the login page when signed out):
            #   AUTHENTICATE = Rodauth::Rails.authenticate(:admin)
            #
            #   def self.matches?(request)
            #     AUTHENTICATE.call(request)
            #   end

            def self.matches?(request)
              false # TODO: Implement authentication
              # Examples:
              #   Devise:     request.env["warden"].user(:admin).present?
              #   Custom:     request.session[:admin_id].present?
              #   HTTP Basic: authenticate_with_http_basic(request)
            end

            # HTTP Basic Auth example:
            # def self.authenticate_with_http_basic(request)
            #   auth = Rack::Auth::Basic::Request.new(request.env)
            #   return false unless auth.provided? && auth.basic?
            #
            #   username, password = auth.credentials
            #   ActiveSupport::SecurityUtils.secure_compare(username, ENV["ADMIN_USERNAME"]) &&
            #     ActiveSupport::SecurityUtils.secure_compare(password, ENV["ADMIN_PASSWORD"])
            # end
          end
        RUBY
      end

      # Returns the `Rodauth::Rails.authenticate` argument for the account that
      # should guard management routes — only ever the `:admin` configuration.
      # `nil` when the app has no admin account, so the constraint is left
      # unimplemented rather than silently handing management routes to whatever
      # other account happens to exist.
      def rodauth_management_account
        rodauth_app = File.expand_path("app/rodauth/rodauth_app.rb", destination_root)
        return unless File.exist?(rodauth_app)

        names = File.read(rodauth_app).scan(/^\s*configure\s+::\w+\s*,\s*:(\w+)/).flatten
        ":admin" if names.include?("admin")
      end
    end
  end
end
