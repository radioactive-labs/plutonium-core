# frozen_string_literal: true

module Plutonium
  module Rbac
    # Per-request (and per-job) RBAC state. Rails resets CurrentAttributes
    # between requests and jobs.
    #
    # - permission_cache: holder -> Set of keys, so a 50-row table runs one query.
    # - holder_cache: (user, entity_scope, portal) -> holder, so a table that
    #   builds a policy per row resolves the holder once.
    # - portal: the portal module (OrgPortal) the request or run belongs to, or
    #   nil. Set beside actor_resolver; picks the portal's rbac_holder override.
    # - actor_resolver: set by controllers and async runs; a lambda returning
    #   the acting holder. Its presence turns on the escalation guard. Absent in
    #   console, seeds and sync, where there is no acting user.
    # - permission_override: testing hook (Plutonium::Testing::Rbac).
    class Current < ActiveSupport::CurrentAttributes
      attribute :permission_cache, :holder_cache, :actor_resolver, :portal, :permission_override

      def permission_keys_for(holder)
        return permission_override if permission_override
        return Set.new if holder.nil?

        self.permission_cache ||= {}
        permission_cache[[holder.class.polymorphic_name, holder.id]] ||= holder.rbac_permission_keys_uncached
      end

      # Rbac.holder_for in the current portal, memoized. nil (no holder) is
      # cached too.
      def holder_for(user:, entity_scope:)
        self.holder_cache ||= {}
        key = [user&.class&.name, user&.id, entity_scope&.class&.name, entity_scope&.id, portal&.name]
        return holder_cache[key] if holder_cache.key?(key)

        holder_cache[key] = Rbac.holder_for(user:, entity_scope:, portal:)
      end

      def enforcing? = !actor_resolver.nil?

      def actor = actor_resolver.call

      def invalidate! = self.permission_cache = nil
    end
  end
end
