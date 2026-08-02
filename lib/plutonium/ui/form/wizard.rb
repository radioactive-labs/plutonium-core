# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      # Renders the CURRENT wizard step through the existing resource-form pipeline
      # (§7). It rides `Form::Resource` unchanged — the only wizard-specific wiring
      # is the per-step adapter (`resource_definition`), the value source (the
      # wizard's typed `data`, so inputs render seeded from staged data for
      # resume/back, including repeater rows), the `wizard[...]` param namespace,
      # the step POST URL, and a hidden `_direction` (default `next`).
      class Wizard < Resource
        # @param step    [Plutonium::Wizard::Step]
        # @param data    [Object] the wizard's typed `data` snapshot (the form
        #   `object`; responds to every step attribute / structured input name).
        # @param action  [String] the current step's POST URL.
        # @param fields  [Array<Symbol>] the step's renderable field names
        #   (scalar attributes + structured inputs).
        # @param wizard  [Plutonium::Wizard::Base, nil] the run being rendered,
        #   used to resolve a step's proc-valued options against. Optional so an
        #   existing caller keeps working; without it those options pass through
        #   unresolved, as they do on every other form.
        def initialize(step:, data:, action:, fields:, wizard: nil, **options, &)
          @step = step
          @wizard = wizard
          options[:key] = :wizard
          options[:as] = :wizard
          options[:action] = action
          options[:resource_fields] = fields
          options[:resource_definition] = Plutonium::Wizard::StepAdapter.new(step)
          options[:singular_resource] = true
          super(data, **options, &)
        end

        private

        attr_reader :step, :wizard

        # A step block is instance_exec'd against a FieldCapture when the wizard
        # class loads, so a proc declared there closes over a recorder that holds
        # nothing. Resolve it against the wizard instead, which is where the rest
        # of the wizard DSL already points:
        #
        #   input :tier, as: :select, choices: -> { anchor.available_tiers }
        #
        # Same receiver a step's `condition:` gets (see Wizard::Runner), so
        # `anchor`, `data`, `persisted` and `current_user` read the same in an
        # option as they do everywhere else in the wizard.
        #
        # `condition:` is excluded here. A FIELD's condition is evaluated against
        # the form, where `object` is this step's staged data; only a STEP's
        # condition belongs to the wizard.
        def resolve_option_procs(options)
          return options if options.blank? || wizard.nil?

          options.to_h do |key, value|
            [key, (key != :condition && value.is_a?(Proc)) ? wizard.instance_exec(&value) : value]
          end
        end

        def form_template
          # The direction defaults to "next"; the nav buttons in the page override
          # it per-button. The wizard Stimulus controller targets it.
          input(type: :hidden, name: "_direction", value: "next", data: {wizard_target: "direction"})
          render_fields
        end

        # The wizard form has no submit footer of its own — the page renders the
        # Back/Next/Finish/Cancel strip. (We still override the resource actions
        # away so no stray "Create"/"Update" button appears.)
        def render_actions
        end

        # The step form sits INSIDE the wizard card body (which already supplies the
        # surface + padding), so drop the default `pu-card my-4 p-8` form chrome —
        # otherwise it reads as a card-in-card. Keep just the vertical field rhythm.
        def form_class
          "space-y-6"
        end

        attr_reader :form_action

        def initialize_attributes
          super
          attributes[:id] = "wizard-form"
        end
      end
    end
  end
end
