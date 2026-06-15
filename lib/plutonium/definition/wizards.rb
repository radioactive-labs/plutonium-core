# frozen_string_literal: true

module Plutonium
  module Definition
    # The `wizard` definition macro (§5.1) — sugar over the Action system, mirroring
    # {Plutonium::Definition::Actions}. It registers a launching action for a
    # portal-hosted wizard on a resource:
    #
    #   class CompanyDefinition < Plutonium::Resource::Definition
    #     wizard :configure, ConfigureCompanyWizard            # anchored → record action
    #     wizard :onboard,   CompanyOnboardingWizard           # no anchor → resource action
    #     wizard :archive,   ArchiveWithReasonWizard, record_action: true  # override
    #   end
    #
    # Placement mirrors interactions: an anchored wizard becomes a **record** action;
    # a non-anchored wizard becomes a **resource** (collection) action. Bulk wizards
    # are not supported (§5.1) — wizards are per-instance flows.
    #
    # The synthesized action's URL is resolved by a proc that builds the wizard's
    # GET route for the subject (the first step). It relies on the wizard routes
    # being drawn for that resource (via `register_wizard` portal-relative, or
    # per-resource wizard member routes); the proc resolves the path at render time.
    module Wizards
      extend ActiveSupport::Concern

      class_methods do
        # @param name [Symbol] the action key (e.g. :configure)
        # @param wizard_class [Class] a Plutonium::Wizard::Base subclass
        # @param record_action [Boolean, nil] force record (member) placement
        # @param collection [Boolean, nil] force resource (collection) placement
        # @param at [String, nil] the wizard's portal-relative base path; defaults
        #   to the wizard's route name (used to build the launch URL)
        def wizard(name, wizard_class, record_action: nil, collection: nil, at: nil, **opts)
          anchored = wizard_class.anchored?
          is_record =
            if !record_action.nil?
              record_action
            elsif !collection.nil?
              !collection
            else
              anchored
            end

          base_path = (at || wizard_route_name(wizard_class)).to_s
          resolver = wizard_launch_resolver(wizard_class, base_path, is_record)

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
            confirmation: opts[:confirmation]
          )
        end

        private

        def wizard_route_name(wizard_class)
          wizard_class.name.demodulize.underscore.sub(/_wizard\z/, "")
        end

        def wizard_label(wizard_class, name)
          if wizard_class.respond_to?(:label) && wizard_class.label.present?
            wizard_class.label
          else
            name.to_s.humanize
          end
        end

        # A url_resolver proc (§5.1). Evaluated against the controller with the
        # subject; builds the wizard's first-step GET URL. The wizard's first step
        # is the entry point — the controller redirects to the resolved step.
        def wizard_launch_resolver(wizard_class, base_path, is_record)
          first_step = wizard_class.steps.first&.key
          helper = :"#{base_path}_wizard_path"

          proc do |subject|
            args = {step: first_step}
            args[:id] = subject if is_record && subject

            engine = current_engine.routes.url_helpers
            if engine.respond_to?(helper)
              engine.public_send(helper, **args)
            else
              url_for(controller: "wizards", action: :show,
                wizard_class: wizard_class.name, **args)
            end
          end
        end
      end
    end
  end
end
