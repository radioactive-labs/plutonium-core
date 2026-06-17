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
            "can't resolve it#{via ? " (no `#{via}` here)" : ""}. Pass `anchor:` to " \
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

      # The entry URL for the wizard's first step (§5.3). Derives the
      # +register_wizard+ route helper name (`<name>_wizard`) and calls it with the
      # wizard's first step. Override for a custom mount / helper name.
      def wizard_entry_path(wizard_class)
        helper = wizard_entry_path_helper(wizard_class)
        first_step = wizard_class.steps.first&.key
        public_send(helper, step: first_step)
      end

      def wizard_entry_path_helper(wizard_class)
        name = wizard_class.name.demodulize.underscore.sub(/_wizard\z/, "")
        :"#{name}_wizard_path"
      end
    end
  end
end
