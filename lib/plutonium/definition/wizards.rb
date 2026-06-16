# frozen_string_literal: true

module Plutonium
  module Definition
    # The `wizard` definition macro (§5.1) — sugar over the Action system, mirroring
    # {Plutonium::Definition::Actions}. It registers a launching action for a
    # wizard auto-mounted on the resource's own controller (see
    # {Plutonium::Resource::Controllers::WizardActions}):
    #
    #   class CompanyDefinition < Plutonium::Resource::Definition
    #     wizard :configure, ConfigureCompanyWizard            # anchored → record action
    #     wizard :onboard,   CompanyOnboardingWizard           # no anchor → resource action
    #     wizard :archive,   ArchiveWithReasonWizard, record_action: true  # override
    #   end
    #
    # Placement mirrors interactions: an **anchored** wizard becomes a **record**
    # action (the anchor is the URL `:id`, resolved through the resource controller's
    # scoped, policy-gated `resource_record!`); a **non-anchored** wizard becomes a
    # **resource** (collection) action. Bulk wizards are not supported (§5.1) —
    # wizards are per-instance flows.
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

        # @param name [Symbol] the action key (e.g. :configure)
        # @param wizard_class [Class] a Plutonium::Wizard::Base subclass
        # @param record_action [Boolean, nil] force record (member) placement
        # @param collection [Boolean, nil] force resource (collection) placement
        def wizard(name, wizard_class, record_action: nil, collection: nil, **opts)
          is_record =
            if !record_action.nil?
              record_action
            elsif !collection.nil?
              !collection
            else
              # Placement mirrors interactions: anchored → record action.
              wizard_class.anchored?
            end

          registered_wizards[name.to_sym] = {wizard_class:, record_action: is_record}

          resolver = wizard_launch_resolver(name, is_record)

          action(
            name,
            route_options: Plutonium::Action::RouteOptions.new(
              method: :get, url_resolver: resolver
            ),
            record_action: is_record,
            resource_action: !is_record,
            category: opts.fetch(:category, :primary),
            icon: opts[:icon],
            position: opts[:position],
            label: opts[:label] || wizard_label(wizard_class, name),
            confirmation: opts[:confirmation],
            condition: wizard_launch_condition(wizard_class, opts[:condition])
          )
        end

        private

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

        # A url_resolver proc (§5.1). Evaluated against the controller with the
        # subject; builds the wizard's first-step GET URL on the auto-mounted
        # resource route — the member route for an anchored wizard (id from the
        # subject), the collection route otherwise. The first step is the entry
        # point; the controller redirects to the resolved step.
        def wizard_launch_resolver(name, is_record)
          wizard_name = name.to_s

          proc do |subject|
            wizard_class = current_definition.class.registered_wizards.fetch(name.to_sym)[:wizard_class]
            first_step = wizard_class.steps.first&.key

            if is_record
              resource_url_for(subject, wizard: wizard_name, step: first_step)
            else
              resource_url_for(resource_class, wizard: wizard_name, step: first_step)
            end
          end
        end
      end
    end
  end
end
