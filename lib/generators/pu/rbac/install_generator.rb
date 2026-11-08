# frozen_string_literal: true

require_relative "../lib/plutonium_generators"

module Pu
  module Rbac
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ResourceRegistration

      source_root File.expand_path("templates", __dir__)

      desc(
        "Enable experimental RBAC, wire role holders and the policy mixin, and connect roles to a portal\n\n" \
        "e.g. rails g pu:rbac:install --holders=OrganizationUser:organization User --dest=org_portal"
      )

      class_option :holders, type: :array, required: true,
        desc: "Holder models, optionally with their tenant association (OrganizationUser:organization)"
      class_option :policy, type: :string, default: "ResourcePolicy",
        desc: "Policy class that receives Plutonium::Rbac::Policy"
      class_option :user_association, type: :string, default: "user",
        desc: "Association from a membership holder to the user"
      class_option :skip_portal, type: :boolean, default: false,
        desc: "Do not connect the role resource to a portal"

      Holder = Struct.new(:class_name, :association)

      def start
        configure_plutonium "config.rbac.enabled = true"
        template "config/initializers/rbac.rb"
        holders.each { |holder| wire_holder(holder) }
        wire_policy
        wire_holder_resolver
        connect_portal unless options[:skip_portal]
        reminders
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      attr_reader :app_namespace

      def holders
        @holders ||= options[:holders].map { |spec| Holder.new(*spec.split(":", 2)) }
      end

      # A holder with a tenant association answers inside an entity scope; one
      # without (usually User or Admin) answers outside it.
      def membership_holder = holders.find(&:association)

      def user_holders = holders.reject(&:association)

      def wire_holder(holder)
        path = source_file_for(holder.class_name, "models")
        include_in_class path, "Plutonium::Rbac::Holder"
        return unless holder.association

        inject_into_file path, "#{class_body_indent(path)}def rbac_entity = #{holder.association}\n\n",
          before: /^ *# add methods above\./
      end

      # `def create? = true` or the multi-line form pu:core:install generates,
      # plus one blank line after it.
      PERMISSIVE_PREDICATE = /^( *)def (create|read)\?(?: = true|\n *true\n\1end) *\n(?:[ \t]*\n)?/

      # Methods defined in the class beat the included mixin, so the
      # always-true create?/read? that pu:core:install generates would keep
      # those actions open to everyone.
      def wire_policy
        path = source_file_for(options[:policy], "policies")
        include_in_class path, "Plutonium::Rbac::Policy"
        remove_permissive_predicates(path)
      end

      # Always ::ResourcePolicy, even when --policy names another class for the
      # mixin: RBAC resolves the holder through it and nowhere else.
      def wire_holder_resolver
        path = "app/policies/resource_policy.rb"
        file = File.join(destination_root, path)
        content = File.read(file)
        return if content.match?(/^ *def rbac_holder\b/)

        lines = rbac_holder_body.map { |line| line.empty? ? "\n" : "    #{line}\n" }.join
        method = "  # Who holds roles for `user` in `entity_scope`. nil means no permissions.\n" \
          "  def rbac_holder\n#{lines}  end\n"
        method = "\n#{method}" unless content.match?(/^class .*\nend\s*\z/)
        inject_into_file path, method, before: /^end\s*\z/
      end

      def rbac_holder_body
        return ["user"] unless membership_holder

        user_key = (options[:user_association] == "user") ? "user:" : "#{options[:user_association]}: user"
        lookup = "#{membership_holder.class_name}.find_by(#{user_key}, #{membership_holder.association}: entity_scope)"
        # The class memberships point at holds roles outside a tenant only;
        # any other class (Admin) holds them everywhere.
        tenantless, standalone = user_holders.partition { |holder| holder.class_name == options[:user_association].camelize }
        body = standalone.map { |holder| "return user if user.is_a?(#{holder.class_name})" }
        return body + ["return user unless entity_scope", "", lookup] if tenantless.any?

        body + ["#{lookup} if entity_scope"]
      end

      def remove_permissive_predicates(path)
        file = File.join(destination_root, path)
        File.read(file).scan(PERMISSIVE_PREDICATE).each do |(_indent, name)|
          log :remove, "#{name}? from #{path} (always true; the rbac policy decides it now)"
        end
        gsub_file path, PERMISSIVE_PREDICATE, "", verbose: false

        File.read(file).scan(/^ *def (create|read)\?/).flatten.each do |name|
          log :warn, "#{path} still defines #{name}?, which overrides the rbac permission check; review it"
        end
      end

      def include_in_class(path, mod)
        inject_into_file path, "#{class_body_indent(path)}include #{mod}\n", after: /^ *class .*\n/
      end

      # A class nested in `module Hr` is indented, so its body is too.
      def class_body_indent(path)
        "#{File.read(File.join(destination_root, path))[/^( *)class /, 1]}  "
      end

      # app/<kind>/<path>.rb, or packages/<pkg>/app/<kind>/<path>.rb
      def source_file_for(class_name, kind)
        relative = "#{class_name.underscore}.rb"
        packaged = Dir[File.join(destination_root, "packages/*/app/#{kind}/#{relative}")]
          .map { |path| path.delete_prefix("#{destination_root}/") }
        (["app/#{kind}/#{relative}"] + packaged).find { |path| File.exist?(File.join(destination_root, path)) } ||
          raise("Could not find #{class_name} in app/#{kind} or packages/*/app/#{kind}")
      end

      def connect_portal
        @app_namespace = portal_option(:dest, prompt: "Select destination portal").camelize

        template "app/controllers/rbac_roles_controller.rb", controller_path
        register_resource_in_routes(routes_path, "Plutonium::Rbac::Role")
      end

      # Not run for you: the migration path is registered from the initializer at
      # BOOT, and this process booted before the flag was written.
      def reminders
        log :info, "rbac enabled: run `rails db:migrate`, then `rails plutonium:rbac:sync` to create system roles"
        log :info, "remove hand-written create?/read? overrides from other policies that should use permissions"
      end

      # main_app is a valid destination (see PackageSelector#available_portals),
      # and it has neither a packages/ tree nor a Concerns::Controller to include.
      def main_app? = app_namespace == "MainApp"

      def package_namespace = app_namespace.underscore

      def controller_path
        return "app/controllers/rbac_roles_controller.rb" if main_app?

        "packages/#{package_namespace}/app/controllers/#{package_namespace}/rbac_roles_controller.rb"
      end

      def routes_path
        main_app? ? "config/routes.rb" : "packages/#{package_namespace}/config/routes.rb"
      end
    end
  end
end
