# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      # The full-page wizard step page (§7). Composes the stepper, the current
      # step's form (or the terminal review summary), and the Back / Next / Finish /
      # Cancel navigation strip — all carrying `_direction`. Rendered inside the
      # portal layout exactly like a resource page; in a turbo frame (modal) the
      # layout is dropped by the controller.
      #
      # The step form rides the existing resource-form pipeline through a per-step
      # adapter, seeded from the wizard's typed `data` so inputs (including repeater
      # rows) rehydrate from staged data on GET — the resume/back requirement.
      class Wizard < Plutonium::UI::Page::Base
        # @param runner   [Plutonium::Wizard::Runner]
        # @param step_url [String] the current step's POST/GET URL.
        # @param errors   [Hash{Symbol=>Array<String>}] runner errors (per-field + :base).
        def initialize(runner:, step_url:, errors: nil)
          @runner = runner
          @step_url = step_url
          @errors = errors || {}
          super(page_title: wizard_title, page_description: nil)
        end

        def view_template(&)
          DynaFrameContent() do
            article(class: "pu-wizard", data: {controller: "wizard"}) do
              render_page_header
              render_stepper
              render_body
            end
          end
        end

        private

        def wizard_title
          step = @runner.current_step
          [@runner.wizard.class.label, step&.label].compact.join(" — ").presence || "Wizard"
        end

        def render_page_header
          PageHeader(title: @runner.wizard.class.label, description: nil, actions: nil)
        end

        def render_stepper
          render Plutonium::UI::Wizard::Stepper.new(
            steps: @runner.visible_path,
            current: @runner.current_step,
            visited: @runner.visited_keys,
            navigation: @runner.wizard.class.navigation,
            step_url: method(:url_for_step)
          )
        end

        def render_body
          step = @runner.current_step
          if step&.review?
            render_review_body(step)
          else
            render_step_form(step)
          end
        end

        # --- step form --------------------------------------------------------

        def render_step_form(step)
          seed_errors!(step)
          render Plutonium::UI::Form::Wizard.new(
            step:,
            data: @runner.wizard.data[step.key],
            action: @step_url,
            fields: step_fields(step),
            errors: form_error_messages(step)
          )
          render_nav(finish: false)
        end

        # The step's renderable field names: scalar attributes + structured inputs.
        def step_fields(step)
          step.attribute_schema.keys.map(&:to_sym) + step.structured_inputs.keys.map(&:to_sym)
        end

        # --- review -----------------------------------------------------------

        def render_review_body(step)
          seed_errors!(step)
          div(class: "mb-5") do
            h2(class: "text-xl font-semibold text-[var(--pu-text)]") { step.label.to_s }
            p(class: "mt-1 text-sm text-[var(--pu-text-muted)]") { "Check everything over before you finish." }
          end
          render_base_errors
          form(action: @step_url, method: "post", id: "wizard-form", data: {controller: "wizard"}) do
            authenticity_field
            input(type: :hidden, name: "_direction", value: "next", data: {wizard_target: "direction"})
            render Plutonium::UI::Wizard::Review.new(runner: @runner, step_url: method(:url_for_step))
            render_nav(finish: true, embedded: true)
          end
        end

        # --- navigation strip -------------------------------------------------

        # @param finish   [Boolean] last visible step → primary button is Finish.
        # @param embedded [Boolean] the strip is already inside a <form> (review);
        #   otherwise wrap each button in its own posting form.
        def render_nav(finish:, embedded: false)
          finish_disabled = finish && @runner.incomplete_visible_steps.any?

          div(class: "pu-wizard-nav mt-8 flex items-center justify-between gap-3 border-t border-[var(--pu-border)] pt-5") do
            div(class: "flex items-center gap-2") do
              nav_button("Back", direction: "back", style: "pu-btn-outline", embedded:) if show_back?
              nav_button("Cancel", direction: "cancel", style: "pu-btn-ghost", embedded:)
            end
            div(class: "flex items-center gap-2") do
              if finish
                nav_button("Finish", direction: "next", style: "pu-btn-primary", embedded:, disabled: finish_disabled, name: "finish")
              else
                nav_button("Next", direction: "next", style: "pu-btn-primary", embedded:, name: "next")
              end
            end
          end
        end

        def show_back?
          path = @runner.visible_path
          current = @runner.current_step
          idx = path.index { |s| s.key.to_s == current&.key.to_s }
          idx && idx > 0
        end

        # A nav button. When `embedded`, it is a plain submit inside the surrounding
        # <form> (review). Otherwise it's its own mini-form posting to the step URL
        # so the step form (Next) and Back/Cancel submit independently.
        def nav_button(label, direction:, style:, embedded:, disabled: false, name: nil)
          data = {wizard_nav: name || direction}
          # Back/Cancel post WITHOUT the step's field values, so any unsaved edits
          # on the current step are discarded. Mark them so the (already-attached)
          # dirty-form-guard warns before that loss. Next/Finish save, so no guard.
          data["dirty-form-guard-leave"] = leave_warning(direction) if %w[back cancel].include?(direction)

          if embedded
            button(
              type: :submit, name: "_direction", value: direction,
              class: "pu-btn pu-btn-md #{style}", disabled: disabled || nil,
              data:
            ) { label }
          elsif direction == "next"
            # Next submits the step form (which holds the inputs). The page's nav
            # Next button is associated with the wizard form via the `form` attr.
            button(
              type: :submit, form: "wizard-form", name: "_direction", value: "next",
              class: "pu-btn pu-btn-md #{style}", disabled: disabled || nil,
              data:
            ) { label }
          else
            # Back/Cancel post on their own — no field validation, so an independent
            # mini-form carrying only _direction is correct.
            form(action: @step_url, method: "post", class: "inline") do
              authenticity_field
              input(type: :hidden, name: "_direction", value: direction)
              button(
                type: :submit,
                class: "pu-btn pu-btn-md #{style}",
                data:
              ) { label }
            end
          end
        end

        # Confirmation copy shown by dirty-form-guard when the current step has
        # unsaved edits and the user clicks a control that abandons them.
        def leave_warning(direction)
          case direction
          when "back" then "You have unsaved changes on this step. Go back and lose them?"
          when "cancel" then "You have unsaved changes. Cancel the wizard and lose them?"
          end
        end

        # --- errors -----------------------------------------------------------

        # Push runner errors onto the CURRENT step's typed sub-object (the form
        # object), so the form/field error chrome renders them. A review step has no
        # sub-object (base errors render separately) — no-op there.
        def seed_errors!(step)
          return if @errors.blank?

          obj = @runner.wizard.data[step.key]
          return unless obj

          obj.errors.clear
          @errors.each do |attr, messages|
            Array(messages).each { |m| obj.errors.add(attr.to_sym, m) }
          end
        end

        def form_error_messages(step)
          return nil if @errors.blank?

          obj = @runner.wizard.data[step.key]
          obj&.errors&.full_messages
        end

        # Base (form-level) errors for the review step (which has no field form to
        # surface them).
        def render_base_errors
          base = Array(@errors[:base]) | Array(@errors["base"])
          return if base.empty?

          div(class: "rounded-lg border border-danger-200 bg-danger-50 dark:border-danger-800 dark:bg-danger-950/30 p-4 mb-4", role: "alert") do
            ul(class: "space-y-1") do
              base.each { |m| li(class: "text-sm text-danger-700 dark:text-danger-400") { m } }
            end
          end
        end

        def authenticity_field
          token = helpers.form_authenticity_token
          input(type: :hidden, name: "authenticity_token", value: token)
        end

        # Build the GET URL for another step by swapping the trailing :step segment
        # of the current step URL.
        def url_for_step(step_key)
          base = @step_url.delete_suffix("/#{@runner.current_step&.key}")
          "#{base}/#{step_key}"
        end

        def page_type = :wizard_page
      end
    end
  end
end
