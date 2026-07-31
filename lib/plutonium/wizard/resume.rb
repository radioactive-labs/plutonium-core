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
        # The DELETE target that abandons this run, resolved from the same mount as
        # `resume_url`. nil when the mount exposes no cancel route.
        :cancel_url,
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
      # Optional +anchor:+/+wizard:+ filters narrow IN THE QUERY (before enrichment)
      # so discarded rows are never URL-resolved or anchor-loaded — cheaper than
      # filtering the returned array. Both compose; the `wizard + anchor` pair is
      # index-covered by `[:wizard, :anchor_type, :anchor_id, :status]`.
      #
      # @param view_context [ActionView::Base] the current view context
      # @param anchor [ActiveRecord::Base, nil] narrow to runs anchored against this record
      # @param wizard [Class, nil] narrow to runs of this wizard class
      # @return [Array<Entry>]
      def entries_for(view_context, anchor: nil, wizard: nil)
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

        relation = Session.status_in_progress.where(owner: owner, engine: engine, scope: scope)
        relation = relation.where(anchor: anchor) if anchor
        relation = relation.where(wizard: wizard.name) if wizard

        relation
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
          cancel_url: resolved[:cancel_url],
          resume_unresolved_reason: resolved[:reason],
          session: row
        )
      end

      def resolve_step(wizard_class, key)
        return nil if key.blank?

        wizard_class.steps.find { |s| s.key.to_s == key.to_s }
      end

      # Resolves a single row to its resume + cancel URLs in the current portal.
      #
      # Both URLs come from the SAME resolved mount, through named route helpers —
      # the cancel target is never derived by string-surgery on the resume URL,
      # which would drop query params and break for a run whose `current_step` is
      # still nil (there the resume URL is the bare launch path, so lopping off its
      # last segment yields a non-route).
      class ResumeUrl
        # How this row's wizard is reachable in the current portal.
        #
        # - +:register_wizard+ — a standalone `register_wizard` mount. `subject` is
        #   the GET route's name, resolved within `route_set`.
        # - +:member+ — a resource-mounted ANCHORED wizard. `subject` is the anchor
        #   record.
        # - +:collection+ — a resource-mounted non-anchored wizard. `subject` is the
        #   resource class whose definition registers it.
        Mount = Struct.new(:kind, :subject, :wizard_name, :route_set)

        def initialize(row, wizard_class, view_context)
          @row = row
          @wizard_class = wizard_class
          @view_context = view_context
        end

        # @return [Hash] {url:, cancel_url:, reason:} — `reason` is non-nil exactly
        #   when no resume URL could be built. The two URLs resolve INDEPENDENTLY:
        #   a run with no `current_step` has no stepped resume URL, but is still
        #   perfectly cancellable, and leaving the user no way to clear it would
        #   strand the row in their chooser forever.
        def resolve
          return {url: nil, cancel_url: nil, reason: unresolved_reason} if mount.nil?

          url = build_step_url(mount)
          {url: url, cancel_url: build_cancel_url(mount), reason: url.nil? ? unresolved_reason : nil}
        end

        private

        # The first mount that claims this row, in precedence order: a standalone
        # `register_wizard` route, then the row's anchor, then a resource definition
        # that registers this wizard as a collection (non-anchored) mount.
        def mount
          return @mount if defined?(@mount)

          @mount = register_wizard_mount || resource_member_mount || resource_collection_mount
        end

        # A `register_wizard` route is named and carries `defaults[:wizard_class]`.
        def register_wizard_mount
          return @register_wizard_mount if defined?(@register_wizard_mount)

          @register_wizard_mount = route_sets.filter_map { |route_set|
            name = Plutonium::Wizard::RouteResolution.route_name(route_set, @wizard_class, action: "show")
            Mount.new(:register_wizard, name, nil, route_set) if name
          }.first
        end

        # A resource-mounted ANCHORED wizard resolves against the row's anchor and
        # the registering definition's wizard name.
        def resource_member_mount
          anchor = @row.anchor
          return nil if anchor.nil?

          wizard_name = registered_wizard_name_for(anchor.class)
          return nil if wizard_name.nil?

          Mount.new(:member, anchor, wizard_name, nil)
        end

        # A resource-mounted non-anchored (collection) wizard carries no resource
        # identity on the row, so find it the other way round: scan this portal's
        # registered resources for the definition that registers this wizard class.
        #
        # Rescued as a whole — `current_engine` is nil (or a plain Rails app with no
        # resource register) outside a portal, and `resolve`'s contract is to report
        # a reason rather than raise.
        def resource_collection_mount
          return nil unless @row.anchor.nil?

          engine = @view_context.current_engine
          return nil if engine.nil?

          candidates = engine.resource_register.resources.filter_map { |resource_class|
            name = registered_wizard_name_for(resource_class)
            [resource_class, name] if name
          }.sort_by { |resource_class, _name| resource_class.name }
          return nil if candidates.empty?

          if candidates.size > 1
            Rails.logger.warn do
              "[Plutonium::Wizard] #{@wizard_class.name} is registered on more than one resource " \
                "definition in #{engine.name} (#{candidates.map { |klass, _| klass.name }.join(", ")}); " \
                "resolving its resume URL against #{candidates.first.first.name}"
            end
          end

          resource_class, wizard_name = candidates.first
          Mount.new(:collection, resource_class, wizard_name, nil)
        rescue => e
          Rails.logger.warn { "[Plutonium::Wizard] collection mount lookup failed for #{@wizard_class.name}: #{e.message}" }
          nil
        end

        # Reverse-lookup the `wizard`-macro name registered for this wizard class on
        # a resource's definition. nil when the definition can't be loaded or doesn't
        # register this wizard.
        def registered_wizard_name_for(resource_class)
          definition = "#{resource_class.name}Definition".safe_constantize
          return nil unless definition.respond_to?(:registered_wizards)

          definition.registered_wizards.find do |_name, reg|
            reg[:wizard_class] == @wizard_class
          end&.first
        end

        # The GET URL that resumes the run at its current step.
        #
        # For a resource mount this is the SAME `resource_url_for(subject, wizard:,
        # step:)` machinery the launch button uses (§5.1) — portal- and scope-correct
        # by construction (it resolves on the current portal's `current_engine`,
        # threads the entity segment when the portal is path-scoped, and singularizes
        # the member helper).
        def build_step_url(mount)
          if mount.kind == :register_wizard
            build_url(mount.route_set, mount.subject, register_wizard_params)
          else
            resource_wizard_url(mount, step: @row.current_step)
          end
        end

        # The DELETE target that abandons the run, from the same mount's named cancel
        # route. nil when the mount predates the cancel route (or generation fails) —
        # the caller then renders no cancel affordance.
        def build_cancel_url(mount)
          if mount.kind == :register_wizard
            name = Plutonium::Wizard::RouteResolution.route_name(mount.route_set, @wizard_class, action: "cancel")
            name && build_url(mount.route_set, name, scope_param.merge(token_param))
          else
            resource_wizard_url(mount, wizard_action: :cancel)
          end
        end

        def resource_wizard_url(mount, **extra)
          @view_context.resource_url_for(mount.subject, wizard: mount.wizard_name, **token_param, **extra)
        rescue => e
          Rails.logger.warn { "[Plutonium::Wizard] url build failed for #{@wizard_class.name}: #{e.message}" }
          nil
        end

        # Params for a `register_wizard` named helper: the current step, the tenant
        # scope path segment (when the run is scoped), and the URL token for a
        # tokened (no concurrency_key) run.
        def register_wizard_params
          {step: @row.current_step}.merge(scope_param).merge(token_param)
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
          if @row.anchor && registered_wizard_name_for(@row.anchor.class).nil?
            "no `wizard` macro registration found for #{@wizard_class.name} " \
              "on #{@row.anchor.class.name}Definition"
          elsif @row.anchor.nil? && register_wizard_mount.nil?
            "non-anchored wizard — no `register_wizard` route in this portal, and no " \
              "resource definition here registers #{@wizard_class.name}"
          else
            "no route found for #{@wizard_class.name} (not registered via " \
              "register_wizard or a `wizard` macro mount this resolver can reach)"
          end
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
