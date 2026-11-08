# frozen_string_literal: true

module Plutonium
  # Experimental permission-based roles. See docs/guides/rbac.md.
  module Rbac
    class NotConfiguredError < Plutonium::Error; end

    class << self
      # Hand-declared permission for something that is not a single resource
      # action, e.g. `Plutonium::Rbac.permission "reports.view"`.
      def permission(key, label: nil, group: nil)
        key = key.to_s
        declared_permissions[key] = Permission.new(
          key:, resource: nil, action: nil,
          label: label || key.tr(".", " ").humanize,
          group: group || key.split(".").first.humanize
        )
      end

      def declared_permissions = @declared_permissions ||= {}

      # System roles declared in code, upserted by plutonium:rbac:sync.
      def system_role(key, name:, permissions:, description: nil)
        system_roles[key.to_sym] = {key: key.to_s, name:, description:, permissions: permissions.map(&:to_s)}
      end

      def system_roles = @system_roles ||= {}

      # The holder whose roles apply to `user` in `entity_scope`: whatever
      # `rbac_holder` returns on ::ResourcePolicy, or on the portal's
      # <Portal>::ResourcePolicy concern when it overrides it (`super` reaches
      # the ResourcePolicy default). Every consumer goes through here, so a
      # portal gets one answer whether or not a resource has a portal policy.
      def holder_for(user:, entity_scope:, portal: nil)
        return nil if user.nil?

        holder_policy_class(portal).new(Role, user:, entity_scope:).rbac_holder
      end

      # The portal module (OrgPortal) an engine belongs to, or nil for the main
      # app and non-portal engines.
      def portal_for(engine)
        engine.module_parent if engine.include?(Plutonium::Portal::Engine)
      end

      # Cleared on reload, since the cached classes subclass the old ::ResourcePolicy.
      def reset_holder_policies! = @holder_policies = nil

      # Keys the current actor may not grant. Empty when no actor resolver is set.
      def ungrantable_keys(keys)
        return [] unless Current.enforcing?

        granted = Current.permission_keys_for(Current.actor)
        keys.reject { |key| Matcher.grants?(granted, key) }
      end

      private

      def holder_policy_class(portal)
        base = "::ResourcePolicy".safe_constantize
        unless base
          raise NotConfiguredError,
            "RBAC resolves role holders through ResourcePolicy#rbac_holder, but ::ResourcePolicy is not defined. " \
            "Define it with an `rbac_holder` method (rails g pu:rbac:install writes one)."
        end

        concern = portal_holder_concern(portal)
        return base unless concern

        @holder_policies ||= {}
        @holder_policies[[base, concern]] ||= Class.new(base) { include concern }
      end

      def portal_holder_concern(portal)
        return unless portal

        concern = "#{portal.name}::ResourcePolicy".safe_constantize
        return unless concern.instance_of?(Module)

        concern if concern.method_defined?(:rbac_holder) || concern.private_method_defined?(:rbac_holder)
      end
    end
  end
end
