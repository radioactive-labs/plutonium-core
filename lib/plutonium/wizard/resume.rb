# frozen_string_literal: true

module Plutonium
  module Wizard
    # Builds the "continue where you left off" listing (§4.5): for every
    # in-progress {Session} row owned by a user (optionally narrowed to a tenant
    # +scope+), an enriched {Entry} carrying the wizard's label/icon, the current
    # step (+ its label), `updated_at`, and a resolved `resume_url`.
    #
    # A host renders this on a dashboard:
    #
    #   Plutonium::Wizard.in_progress_for(view_context)
    #
    # Resume URLs are resolved by scanning the host's route sets:
    #
    # - A `register_wizard` (portal/public) wizard draws a NAMED route carrying a
    #   `wizard_class` route default; we find it and build the URL from its helper,
    #   threading the tenant scope segment and (for tokened runs) the `:token`.
    # - A `wizard`-macro (resource-mounted) ANCHORED wizard draws a member route
    #   (`.../:id/wizards/:wizard_name/:step`); we resolve it from the row's anchor
    #   + the registering definition's wizard name.
    #
    # When a row's mount can't be resolved generically (e.g. a non-anchored
    # resource-mounted wizard, whose resource identity isn't on the row), the entry
    # is returned with `resume_url: nil` and a `resume_unresolved_reason`, rather
    # than guessing or raising.
    module Resume
      # One enriched in-progress wizard, ready for a dashboard list item.
      Entry = Struct.new(
        :wizard_class,
        :label,
        :icon,
        :current_step,
        :current_step_label,
        :updated_at,
        :resume_url,
        :resume_unresolved_reason,
        :session
      )

      module_function

      # @param owner [Object] the run owner (e.g. current_user)
      # @param scope [Object, nil] tenant scope (REQUIRED keyword); when non-nil,
      #   narrows to that scope; explicit nil (non-scoped portal) → no scope filter
      # @return [Array<Entry>] in-progress entries, newest first
      def entries_for(owner, scope:)
        rel = Session.status_in_progress.where(owner: owner)
        rel = rel.where(scope: scope) unless scope.nil?
        rel.order(updated_at: :desc).filter_map { |row| entry_for(row) }
      end

      # @return [Entry, nil] nil when the wizard class can't be loaded
      def entry_for(row)
        wizard_class = row.wizard.to_s.safe_constantize
        return nil unless wizard_class

        step = resolve_step(wizard_class, row.current_step)
        resolved = ResumeUrl.new(row, wizard_class).resolve

        Entry.new(
          wizard_class: wizard_class,
          label: wizard_class.label,
          icon: wizard_class.icon,
          current_step: row.current_step,
          current_step_label: step&.label,
          updated_at: row.updated_at,
          resume_url: resolved[:url],
          resume_unresolved_reason: resolved[:reason],
          session: row
        )
      end

      def resolve_step(wizard_class, key)
        return nil if key.blank?

        wizard_class.steps.find { |s| s.key.to_s == key.to_s }
      end

      # Resolves a single row to its resume URL by scanning route sets.
      class ResumeUrl
        def initialize(row, wizard_class)
          @row = row
          @wizard_class = wizard_class
        end

        # @return [Hash] {url:, reason:} — exactly one of the two is non-nil.
        def resolve
          if (named = register_wizard_url)
            return {url: named, reason: nil}
          end

          if (member = resource_member_url)
            return {url: member, reason: nil}
          end

          {url: nil, reason: unresolved_reason}
        end

        private

        # A `register_wizard` route is named and carries `defaults[:wizard_class]`.
        def register_wizard_url
          route_sets.each do |route_set|
            route = route_set.routes.find do |r|
              r.name.present? &&
                r.defaults[:action].to_s == "show" &&
                r.defaults[:wizard_class].to_s == @wizard_class.name
            end
            next unless route

            return build_url(route_set, route.name, register_wizard_params)
          end
          nil
        end

        # Params for a `register_wizard` named helper: the current step, the tenant
        # scope path segment (when the run is scoped), and the URL token for a
        # tokened (no concurrency_key) run.
        def register_wizard_params
          {step: @row.current_step}.merge(scope_param).merge(token_param)
        end

        # A resource-mounted ANCHORED wizard draws a member route named
        # `wizard_record_action_<...>`. Resolve it from the row's anchor + the
        # registering definition's wizard name.
        def resource_member_url
          anchor = @row.anchor
          return nil if anchor.nil?

          wizard_name = registered_wizard_name
          return nil if wizard_name.nil?

          route_sets.each do |route_set|
            route = member_route_for(route_set, anchor)
            next unless route

            params = {
              id: anchor.to_param,
              wizard_name: wizard_name,
              step: @row.current_step
            }
            params.merge!(scope_param)
            params.merge!(token_param)
            return build_url(route_set, route.name, params)
          end
          nil
        end

        # Find the resource controller's TOP-LEVEL member wizard route for the
        # anchor's model. The controller is `<model>.pluralize.underscore`,
        # optionally portal-namespaced (e.g. `org_portal/widgets`), so match on the
        # controller suffix. The same model can mount BOTH a top-level and nested
        # member route (the latter requires a parent id we don't have on the row),
        # so prefer the fewest-required-parts (top-level) candidate.
        def member_route_for(route_set, anchor)
          suffix = anchor.class.to_s.pluralize.underscore
          candidates = route_set.routes.select do |r|
            next false unless r.name.present?
            next false unless r.defaults[:action].to_s == "wizard_record_action"

            controller = r.defaults[:controller].to_s
            controller == suffix || controller.end_with?("/#{suffix}")
          end
          # Prefer the TOP-LEVEL mount: fewest required parts, and a non-nested
          # route name (a nested mount, even with a singular parent that adds no
          # :id, would resolve to the wrong canonical URL).
          candidates.min_by do |r|
            [r.required_parts.size, r.name.to_s.include?("_nested_") ? 1 : 0]
          end
        end

        # Reverse-lookup the `wizard`-macro name registered for this wizard class on
        # the anchor's resource definition. nil when not found.
        def registered_wizard_name
          definition = definition_for(@row.anchor)
          return nil unless definition.respond_to?(:registered_wizards)

          definition.registered_wizards.find do |_name, reg|
            reg[:wizard_class] == @wizard_class
          end&.first
        end

        def definition_for(record)
          "#{record.class.name}Definition".safe_constantize
        end

        # The scope path segment for an entity-scoped portal, keyed by the route
        # set's engine scoped_entity_param_key, valued from the row's scope record.
        def scope_param
          scope = @row.scope
          return {} if scope.nil?

          {scoped_entity_param_key => scope.to_param}
        end

        def scoped_entity_param_key
          # All entity-scoped portals key the same way; derive from the scope model.
          scope = @row.scope
          :"#{scope.model_name.singular_route_key}_scoped"
        end

        # A tokened (no concurrency_key) run carries its per-run id in the URL.
        def token_param
          return {} if @wizard_class.concurrency_key?
          return {} if @row.token.blank?

          {token: @row.token}
        end

        def build_url(route_set, route_name, params)
          route_set.url_helpers.public_send(:"#{route_name}_path", **params)
        rescue => e
          Rails.logger.warn { "[Plutonium::Wizard] resume url build failed for #{route_name}: #{e.message}" }
          nil
        end

        def unresolved_reason
          if @row.anchor && registered_wizard_name.nil?
            "no `wizard` macro registration found for #{@wizard_class.name} " \
              "on #{@row.anchor.class.name}Definition"
          elsif @row.anchor.nil? && resource_mounted_candidate?
            "non-anchored resource-mounted wizard — the row carries no resource " \
              "identity to rebuild its collection URL"
          else
            "no route found for #{@wizard_class.name} (not registered via " \
              "register_wizard or a `wizard` macro mount this resolver can reach)"
          end
        end

        # Heuristic for the reason text only: the wizard isn't a register_wizard
        # mount (no named route) and has no anchor on the row.
        def resource_mounted_candidate?
          register_wizard_url.nil?
        end

        # Every Plutonium engine route set plus the main app's (for public mounts).
        def route_sets
          @route_sets ||= begin
            sets = [Rails.application.routes]
            Rails::Engine.subclasses.each do |engine|
              next unless engine.respond_to?(:routes)

              sets << engine.routes
            rescue
              next
            end
            sets.uniq
          end
        end
      end
    end
  end
end
