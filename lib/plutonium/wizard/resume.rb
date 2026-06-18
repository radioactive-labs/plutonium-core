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
    # Resume URLs are built in the CURRENT portal (the one whose `view_context` is
    # passed), so a run is only ever linked from the portal it belongs to:
    #
    # - A `register_wizard` (portal/public) wizard draws a NAMED route carrying a
    #   `wizard_class` route default; we find it and build the URL from its helper,
    #   threading the tenant scope segment and (for tokened runs) the `:token`.
    # - A `wizard`-macro (resource-mounted) ANCHORED wizard's member URL is built by
    #   the same `resource_url_for(record, wizard:, step:)` machinery the launch
    #   button uses — portal- and scope-correct by construction — from the row's
    #   anchor + the registering definition's wizard name.
    #
    # When a row's mount can't be resolved in this portal (e.g. a non-anchored
    # resource-mounted wizard, whose resource identity isn't on the row, or a wizard
    # not mounted here), the entry is returned with `resume_url: nil` and a
    # `resume_unresolved_reason`, rather than guessing or raising.
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

      # In-progress entries for the run owner and tenant scope derived from the
      # current portal's +view_context+ (the same object interactions take). A run
      # belongs to exactly one portal context, so the scope MATCHES it: a scoped
      # portal narrows to its tenant; a non-scoped portal narrows to runs with no
      # scope (never another portal's entity-scoped runs). Resume URLs are built
      # through that same view_context, so they land in THIS portal. Newest first.
      #
      # @param view_context [ActionView::Base] the current view context
      # @return [Array<Entry>]
      def entries_for(view_context)
        controller = view_context.controller
        owner = controller.helpers.current_user
        # A guest has no owner-tracked runs — anonymous runs are session-keyed and
        # ownerless (§4.5). The public surface stubs `current_user` to "Guest", so
        # bail rather than query `where(owner: "Guest")` (a non-record). And never
        # normalize "Guest" to nil: `where(owner: nil)` would match EVERY guest's
        # ownerless run — a cross-guest leak.
        return [] unless owner.present? && owner != "Guest"

        # `current_scoped_entity` is a helper_method — read it off the view context.
        scope = controller.scoped_to_entity? ? view_context.current_scoped_entity : nil
        # The portal pins the listing: a run is only shown by the portal it was
        # launched in. `scope` still isolates the tenant WITHIN a scoped portal —
        # `engine` alone can't (one engine serves every tenant via path scoping).
        engine = view_context.current_engine.name

        Session.status_in_progress
          .where(owner: owner, engine: engine, scope: scope)
          .order(updated_at: :desc)
          .filter_map { |row| entry_for(row, view_context) }
      end

      # @return [Entry, nil] nil when the wizard class can't be loaded
      def entry_for(row, view_context)
        wizard_class = row.wizard.to_s.safe_constantize
        return nil unless wizard_class

        step = resolve_step(wizard_class, row.current_step)
        resolved = ResumeUrl.new(row, wizard_class, view_context).resolve

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

      # Resolves a single row to its resume URL in the current portal.
      class ResumeUrl
        def initialize(row, wizard_class, view_context)
          @row = row
          @wizard_class = wizard_class
          @view_context = view_context
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
            name = Plutonium::Wizard::RouteResolution.route_name(route_set, @wizard_class, action: "show")
            next unless name

            return build_url(route_set, name, register_wizard_params)
          end
          nil
        end

        # Params for a `register_wizard` named helper: the current step, the tenant
        # scope path segment (when the run is scoped), and the URL token for a
        # tokened (no concurrency_key) run.
        def register_wizard_params
          {step: @row.current_step}.merge(scope_param).merge(token_param)
        end

        # A resource-mounted ANCHORED wizard's member URL is built by the SAME
        # `resource_url_for(record, wizard:, step:)` machinery the launch button uses
        # (§5.1) — so it's portal- and scope-correct by construction (it resolves on
        # the current portal's `current_engine`, threads the entity segment when the
        # portal is path-scoped, and singularizes the member helper). We pass the
        # row's anchor as the record, the registering definition's wizard name, and
        # the resumed step; a tokened (non-keyed) run also carries its run token.
        def resource_member_url
          anchor = @row.anchor
          return nil if anchor.nil?

          wizard_name = registered_wizard_name
          return nil if wizard_name.nil?

          @view_context.resource_url_for(anchor, wizard: wizard_name, step: @row.current_step, **token_param)
        rescue => e
          Rails.logger.warn { "[Plutonium::Wizard] resume url build failed for #{@wizard_class.name}: #{e.message}" }
          nil
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

        # The scope path segment for an entity-scoped portal, keyed by the portal
        # engine's own +scoped_entity_param_key+ (which honors a custom +param_key:+
        # passed to +scope_to_entity+), valued from the row's scope record.
        def scope_param
          scope = @row.scope
          return {} if scope.nil?

          {scoped_entity_param_key => scope.to_param}
        end

        # The route's scope param key comes from the engine the resume URL is built
        # in — NOT re-derived from the scope model, which would diverge from the
        # actual route segment whenever the portal set a custom `param_key:`.
        def scoped_entity_param_key
          @view_context.current_engine.scoped_entity_param_key
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

        # The CURRENT portal's route set, plus the main app's (for `public:` mounts).
        # Scoped to this portal so a `register_wizard` wizard mounted in several
        # portals resolves here, not in whichever engine happens to be scanned first.
        def route_sets
          @route_sets ||= [@view_context.current_engine.routes, Rails.application.routes].uniq
        end
      end
    end
  end
end
