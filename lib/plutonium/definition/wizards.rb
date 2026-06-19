# frozen_string_literal: true

module Plutonium
  module Definition
    # The `wizard` definition macro (§5.1) — sugar over the Action system, mirroring
    # {Plutonium::Definition::Actions}. It registers a launching action for a
    # wizard auto-mounted on the resource's own controller (see
    # {Plutonium::Resource::Controllers::WizardActions}):
    #
    #   class CompanyDefinition < Plutonium::Resource::Definition
    #     wizard :configure, ConfigureCompanyWizard                # anchored → record action (show + list)
    #     wizard :configure, ConfigureCompanyWizard, collection_record_action: false  # show page only
    #     wizard :onboard,   CompanyOnboardingWizard               # no anchor → resource action
    #   end
    #
    # Placement is dictated by the wizard, mirroring interactions: an **anchored**
    # wizard is a **record** action (the anchor is the URL `:id`, resolved through the
    # resource controller's scoped, policy-gated `resource_record!`); a **non-anchored**
    # wizard is a **resource** (collection) action. It's not overridable — a flag that
    # doesn't apply to the kind raises. The configurable surface is where a RECORD
    # action shows: the show page (`record_action:`) and the list rows
    # (`collection_record_action:`), both on by default. Bulk wizards are not
    # supported (§5.1) — wizards are per-instance flows.
    #
    # The macro keeps a per-definition registry (`registered_wizards`) the
    # resource-mounted {WizardActions} concern reads to resolve the wizard class by
    # the `:wizard_name` route segment, and synthesizes a launch action whose URL
    # resolver targets the auto-mounted member (anchored) or collection routes.
    module Wizards
      extend ActiveSupport::Concern

      class_methods do
        # @return [Hash{Symbol=>Hash}] registry of wizards declared on this
        #   definition: `{name => {wizard_class:, record_action:}}`. Read by
        #   {Plutonium::Resource::Controllers::WizardActions} to resolve + gate.
        def registered_wizards
          @registered_wizards ||= {}
        end

        # Definitions are inheritable; carry the wizard registry to subclasses.
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@registered_wizards, registered_wizards.dup)
        end

        # Placement is dictated by the wizard, not chosen: an **anchored** wizard is
        # a **record** action (it needs a record — the anchor), a **non-anchored**
        # wizard is a **resource** (collection) action. The only configurable surface
        # is WHERE a *record* action shows — the **show** page (`record_action:`) and
        # the **list** rows (`collection_record_action:`), both on by default. Flags
        # that don't apply to the wizard's kind are rejected.
        #
        # Like an interaction, a `wizard` action is gated by a policy predicate named
        # after its key — `def configure? = update?` for `wizard :configure, …`. The
        # SAME predicate drives both the launch action's visibility
        # (`Action#permitted_by?` on index/show) and its authorization
        # ({WizardActions#authorize_wizard_*_action!}), so the button and the action
        # stay in lockstep. A missing predicate raises `ActionPolicy::UnknownRule`
        # (exactly as a missing interaction predicate does) — define it.
        #
        # @param name [Symbol] the action key (e.g. :configure)
        # @param wizard_class [Class] a Plutonium::Wizard::Base subclass
        # @param opts [Hash] action overrides — chrome (`label:`/`icon:`/`position:`/
        #   `category:`/`confirmation:`/`turbo_frame:`) plus, for a RECORD wizard, the
        #   show/list surface flags `record_action:`/`collection_record_action:`.
        def wizard(name, wizard_class, **opts)
          is_record = wizard_class.anchored?
          reject_inapplicable_surface!(name, wizard_class, is_record, opts)

          registered_wizards[name.to_sym] = {wizard_class:, record_action: is_record}

          resolver = wizard_launch_resolver(name, is_record)

          # A record (anchored) wizard surfaces on BOTH the show page (`record_action`)
          # AND each list row (`collection_record_action`, scoped to that row's
          # record); a resource (non-anchored) wizard is the collection-level
          # `resource_action`. `opts` are spliced AFTER, so a record wizard can opt out
          # of either surface (e.g. `collection_record_action: false` → show page only).
          action(
            name,
            route_options: Plutonium::Action::RouteOptions.new(
              method: :get, url_resolver: resolver
            ),
            label: wizard_label(wizard_class, name),
            icon: wizard_icon(wizard_class),
            category: :primary,
            record_action: is_record,
            collection_record_action: is_record,
            resource_action: !is_record,
            **opts.except(:condition),
            condition: wizard_launch_condition(wizard_class, opts[:condition])
          )
        end

        private

        # Reject surface flags that don't apply to the wizard's kind. Placement is
        # fixed by `anchored?`: a RECORD (anchored) wizard can only be placed on the
        # show page / list rows (`record_action:`/`collection_record_action:`) — it
        # can't be a `resource_action` (there's no record at the collection level); a
        # RESOURCE (non-anchored) wizard is a collection-level action with no record,
        # so the record/list surfaces don't apply.
        def reject_inapplicable_surface!(name, wizard_class, is_record, opts)
          disallowed =
            if is_record
              [:resource_action]
            else
              [:record_action, :collection_record_action]
            end
          bad = disallowed.select { |flag| opts.key?(flag) }
          return if bad.empty?

          kind = is_record ? "anchored (a record action)" : "not anchored (a resource action)"
          applies = is_record ? "record_action: / collection_record_action: (show page / list rows)" : "none (it's the collection-level action)"
          raise ArgumentError,
            "wizard :#{name} — #{wizard_class} is #{kind}; " \
            "#{bad.join(", ")} #{(bad.size == 1) ? "doesn't" : "don't"} apply. " \
            "Configurable surface here: #{applies}."
        end

        # The launch action's `condition:` (§9). A **one-time** wizard's launch is
        # hidden once the current user has already completed it: the condition
        # recomputes the wizard's `instance_key` for the current context (same
        # {Plutonium::Wizard.compute_instance_key} the driving layer + gate use) and
        # returns false when a retained `completed` row exists at that key. A
        # repeatable (non-one-time) wizard gets NO completion condition.
        #
        # When the author also passed a `condition:`, the two are AND-ed: the action
        # shows only if the author's condition is met AND the wizard isn't already
        # completed.
        #
        # The proc runs in a {Plutonium::Action::ConditionContext}: `object`/`record`
        # is the anchor for a record action (nil for a resource action), view helpers
        # (`current_user`) delegate to the view context, and `current_scoped_entity` /
        # `scoped_to_entity?` are read off the host controller (`controller`) exactly
        # as the gate recomputes them.
        def wizard_launch_condition(wizard_class, author_condition)
          return author_condition unless wizard_class.one_time?

          completion_condition = proc do
            # This runs on EVERY index/show render. The `wizard` macro is not gated
            # on `config.wizards.enabled` (only routing is), so guard the DB query:
            # when the subsystem is disabled its routes aren't drawn (a launch button
            # would 404) → hide the action; when it's enabled but the sessions table
            # hasn't been migrated yet, treat the wizard as not-yet-completed (show)
            # rather than raising StatementInvalid mid-render.
            next false unless Plutonium.configuration.wizards.enabled
            next true unless Plutonium::Wizard::Session.table_exists?

            scope =
              if controller.scoped_to_entity?
                controller.current_scoped_entity
              end

            instance_key = Plutonium::Wizard.compute_instance_key(
              wizard_class: wizard_class,
              current_user: current_user,
              current_scoped_entity: scope,
              anchor: wizard_class.anchored? ? object : nil,
              wizard_token: nil
            )

            !Plutonium::Wizard::Store::ActiveRecord.new.completed?(instance_key: instance_key)
          end

          return completion_condition if author_condition.nil?

          # AND the author's condition with the completion check; both run in the
          # same ConditionContext, so evaluate each via instance_exec on self.
          proc do
            instance_exec(&author_condition) && instance_exec(&completion_condition)
          end
        end

        def wizard_label(wizard_class, name)
          if wizard_class.respond_to?(:label) && wizard_class.label.present?
            wizard_class.label
          else
            name.to_s.humanize
          end
        end

        def wizard_icon(wizard_class)
          wizard_class.icon || Phlex::TablerIcons::Wand
        end

        # A url_resolver proc (§5.1). Evaluated against the controller with the
        # subject; builds the wizard's bare LAUNCH URL on the auto-mounted resource
        # route — the member route for an anchored wizard (id from the subject), the
        # collection route otherwise. The launch action resolves the run and
        # redirects to its current step (the resumed cursor for an in-progress keyed
        # run, else the first step), with the token already in the URL — so we never
        # hardcode a step here.
        def wizard_launch_resolver(name, is_record)
          wizard_name = name.to_s

          proc do |subject|
            if is_record
              resource_url_for(subject, wizard: wizard_name)
            else
              resource_url_for(resource_class, wizard: wizard_name)
            end
          end
        end
      end
    end
  end
end
