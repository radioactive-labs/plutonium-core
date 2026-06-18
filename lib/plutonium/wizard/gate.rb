# frozen_string_literal: true

module Plutonium
  module Wizard
    # Controller concern that gates access behind a **one-time wizard** (§9).
    #
    # +ensure_wizard_completed(WizardClass)+ installs a +before_action+ that
    # recomputes the wizard's +instance_key+ (from its +concurrency_key+ — resolved
    # against the host controller's identity context, with the tenant folded in,
    # §4.4) and checks whether a retained +completed+ row exists at that key. If
    # not, it stashes the intended destination and redirects into the wizard's
    # entry step; once the wizard's own finalize retains the completion marker, the
    # gate lets the user through and the controller bounces back to the stashed
    # destination (PRG, wired in {Controller}).
    #
    #   class DashboardController < AdminPortal::PlutoniumController
    #     include Plutonium::Wizard::Gate
    #     ensure_wizard_completed OnboardingWizard
    #   end
    #
    # Only **one-time** wizards (a +concurrency_key+ plus +one_time+) are gateable —
    # they are the only ones with a durable retained marker. Gating any other
    # wizard raises a clear error at install time.
    #
    # The instance_key recomputation MUST match the runner/driving digest exactly
    # (both go through {Plutonium::Wizard.compute_instance_key}), or the gate would
    # never see the completion the wizard recorded.
    module Gate
      extend ActiveSupport::Concern

      class_methods do
        # Install the gating +before_action+. Extra options (e.g. +only:/except:+)
        # are forwarded to +before_action+.
        #
        # +anchor:+ tells the gate how to resolve an ANCHORED wizard's anchor in
        # THIS controller's context (a symbol method name or a proc evaluated on the
        # controller) — required to recompute an anchor-keyed wizard's instance_key.
        # A `via:`-anchored wizard whose anchor method the controller exposes is
        # resolved automatically, so this is only needed when the anchor isn't in
        # scope (e.g. a `with:`-anchored wizard, or gating from another portal).
        def ensure_wizard_completed(wizard_class, anchor: nil, **before_action_opts)
          unless wizard_class.one_time?
            raise ArgumentError,
              "#{wizard_class.name} is not a one-time wizard (needs a " \
              "`concurrency_key` + `one_time`); only one-time wizards are gateable (§9)."
          end

          before_action(**before_action_opts) do
            enforce_wizard_completion!(wizard_class, anchor)
          end
        end
      end

      private

      # The before_action body: pass through when completed, else stash + redirect.
      def enforce_wizard_completion!(wizard_class, anchor_resolver = nil)
        return if wizard_completed?(wizard_class, anchor_resolver)

        session[:return_to] ||= request.fullpath
        redirect_to wizard_entry_path(wizard_class)
      end

      def wizard_completed?(wizard_class, anchor_resolver = nil)
        wizard_gate_store.completed?(instance_key: wizard_gate_instance_key(wizard_class, anchor_resolver))
      end

      # Recompute the wizard's instance_key on the host controller (§9). The
      # identity context (`current_user`, `current_scoped_entity`, `anchor`, custom
      # host methods) is read from this controller; a referenced method that's
      # missing raises a clear error via {compute_instance_key}.
      def wizard_gate_instance_key(wizard_class, anchor_resolver = nil)
        Plutonium::Wizard.compute_instance_key(
          wizard_class: wizard_class,
          current_user: current_user,
          current_scoped_entity: wizard_gate_scoped_entity,
          anchor: wizard_gate_anchor(wizard_class, anchor_resolver),
          wizard_token: nil
        )
      end

      # Resolve an anchored wizard's anchor in this controller's context, so an
      # anchor-keyed wizard's `instance_key` recomputes to the SAME digest the run
      # used (§9). Order: an explicit `anchor:` resolver wins; otherwise a
      # `via:`-anchored wizard whose anchor method the controller exposes is
      # resolved automatically (the same method the wizard uses); otherwise nil — a
      # non-anchored wizard, or an anchor that can't be reached here. The latter is a
      # misconfiguration for an anchor-keyed wizard, so raise rather than mis-key.
      def wizard_gate_anchor(wizard_class, anchor_resolver)
        return resolve_gate_anchor(anchor_resolver) if anchor_resolver
        return nil unless wizard_class.anchored?

        via = wizard_class.anchor_via
        return send(via) if via && respond_to?(via, true)

        # Couldn't auto-resolve the anchor. When the wizard relies on the IMPLIED
        # anchor key, the anchor is DEFINITELY part of the identity, so a nil would
        # silently mis-key (the gate would loop forever) — raise instead. For an
        # explicit key we can't tell whether it references the anchor, so leave it
        # nil (best-effort, same contract as any host-method the key may reference).
        if wizard_class.implied_anchor_key?
          raise ArgumentError,
            "#{wizard_class.name} is anchored and keyed by its anchor, but #{self.class} " \
            "can't resolve it#{" (no `#{via}` here)" if via}. Pass `anchor:` to " \
            "`ensure_wizard_completed` (a method name or proc)."
        end
        nil
      end

      # Evaluate an explicit `anchor:` resolver: a proc runs in the controller
      # context, a symbol is sent to the controller.
      def resolve_gate_anchor(resolver)
        resolver.respond_to?(:call) ? instance_exec(&resolver) : send(resolver)
      end

      # The tenant folded into the gate's key recomputation (§4.4) — the portal
      # scoping entity when the host portal is entity-scoped, else nil. Mirrors the
      # driving layer's `resolved_wizard_scope`. `current_user`/`scoped_to_entity?`
      # are private on portal controllers, so call them directly (a `respond_to?`
      # check would be false for private methods and silently mis-key).
      def wizard_gate_scoped_entity
        return unless scoped_to_entity?

        current_scoped_entity
      end

      def wizard_gate_store
        Plutonium::Wizard::Store::ActiveRecord.new
      end

      # The entry URL for the wizard (§5.3): the bare LAUNCH route `register_wizard`
      # drew, resolved from THIS portal's route set by the wizard's `wizard_class`
      # route default — so the actual `at:`/`as:` used at registration is honored
      # (re-deriving a slug from the class name breaks whenever they differ, e.g.
      # `register_wizard W, at: "onboarding"`). The launch action resolves/mints the
      # run and PRGs to its current (resumed) step, so no `:step` is needed here. The
      # tenant scope path segment is threaded for an entity-scoped portal (the route
      # requires it). Override for a custom mount.
      def wizard_entry_path(wizard_class)
        route_set = wizard_gate_route_set
        name = Plutonium::Wizard::RouteResolution.route_name(route_set, wizard_class, action: "launch")
        unless name
          raise ArgumentError,
            "#{self.class} gates #{wizard_class.name} but no `register_wizard` launch " \
            "route for it was found in #{(route_set === Rails.application.routes) ? "the application" : "this portal"}. " \
            "Register it with `register_wizard #{wizard_class.name}, at: \"…\"`, or override " \
            "`wizard_entry_path` for a custom mount."
        end

        route_set.url_helpers.public_send(:"#{name}_path", **wizard_gate_scope_param)
      end

      # The route set the gated wizard is mounted in — the host portal's engine
      # routes (it's registered alongside the portal's resources). Override if the
      # gate lives outside the wizard's portal.
      def wizard_gate_route_set
        current_engine.routes
      end

      # The tenant scope path segment for an entity-scoped portal, threaded from the
      # current request so the entry URL stays inside the tenant. The route's param
      # key is the engine's own `scoped_entity_param_key` (honors a custom
      # `param_key:`); empty for a non-scoped portal.
      def wizard_gate_scope_param
        return {} unless scoped_to_entity?

        {scoped_entity_param_key => params[scoped_entity_param_key]}
      end
    end
  end
end
