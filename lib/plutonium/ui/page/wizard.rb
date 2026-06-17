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
            article(class: "pu-wizard mx-auto max-w-3xl", data: {controller: "wizard"}) do
              render_header
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

        # Centered wizard header: the title and the wizard-level description
        # (`presents description:`). The per-step heading lives on the step card.
        def render_header
          div(class: "pu-wizard-header mb-7 text-center") do
            h1(class: "text-2xl font-bold tracking-tight text-[var(--pu-text)]") do
              @runner.wizard.class.label
            end
            desc = @runner.wizard.class.description
            if desc.present?
              p(class: "mx-auto mt-1.5 max-w-prose text-[var(--pu-text-muted)]") { desc }
            end
          end
        end

        def render_stepper
          return unless @runner.wizard.class.stepper?

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

        # The focused content card shared by step + review: a body holding the
        # step heading and content, and a footer nav strip.
        def card_classes
          "pu-wizard-card overflow-hidden rounded-[var(--pu-radius-xl)] " \
            "border border-[var(--pu-border)] bg-[var(--pu-surface)] shadow-[var(--pu-shadow-lg)]"
        end

        def card_body_classes = "p-6 sm:p-8"

        # The per-step heading: "Step N of M" + the step's label + its description.
        # The terminal review step is the "finish line", not a numbered step, so it
        # carries no step count (here or in the rail) — just its label + description.
        def render_step_header(step)
          div(class: "mb-6") do
            unless step.review?
              span(class: "text-xs font-bold uppercase tracking-wide text-primary-600 dark:text-primary-400") do
                "Step #{step_position(step)} of #{visible_step_count}"
              end
            end
            h2(class: "mt-1 text-xl font-semibold tracking-tight text-[var(--pu-text)]") { step.label.to_s }
            # The author's own description wins. Otherwise, on a review step, fall
            # back to the "check everything over" prompt ONLY when the summary is
            # shown — when summary is off (the ready panel / custom-only body), that
            # prompt would contradict the body, so we omit it.
            desc = step.description.presence
            desc ||= "Check everything over before you finish." if step.review? && step.summary?
            if desc
              p(class: "mt-1.5 text-sm text-[var(--pu-text-muted)]") { desc }
            end
          end
        end

        # Counts/positions exclude the review step — it's not a numbered step — so
        # the last real step reads "Step N of N" (not "N of N+1" with a missing N+1).
        def visible_step_count = @runner.visible_path.count { |s| !s.review? }

        def step_position(step)
          (@runner.visible_path.reject(&:review?).index { |s| s.key.to_s == step.key.to_s } || 0) + 1
        end

        # --- step form --------------------------------------------------------

        def render_step_form(step)
          seed_errors!(step)
          div(class: card_classes) do
            div(class: card_body_classes) do
              render_step_header(step)
              render Plutonium::UI::Form::Wizard.new(
                step:,
                data: @runner.wizard.data[step.key],
                action: @step_url,
                fields: step_fields(step),
                errors: form_error_messages(step)
              )
            end
            render_nav(finish: false)
          end
        end

        # The step's renderable field names: scalar attributes + structured inputs.
        def step_fields(step)
          step.attribute_schema.keys.map(&:to_sym) + step.structured_inputs.keys.map(&:to_sym)
        end

        # --- review -----------------------------------------------------------

        def render_review_body(step)
          seed_errors!(step)
          div(class: card_classes) do
            form(action: @step_url, method: "post", id: "wizard-form", data: {controller: "wizard"}) do
              div(class: card_body_classes) do
                render_step_header(step) if step.header?
                render_review_errors
                authenticity_field
                input(type: :hidden, name: "_direction", value: "next", data: {wizard_target: "direction"})
                render Plutonium::UI::Wizard::Review.new(runner: @runner, step_url: method(:url_for_step))
              end
              render_nav(finish: true, embedded: true)
            end
          end
        end

        # --- navigation strip -------------------------------------------------

        # @param finish   [Boolean] last visible step → primary button is Finish.
        # @param embedded [Boolean] the strip is already inside a <form> (review);
        #   otherwise wrap each button in its own posting form.
        def render_nav(finish:, embedded: false)
          finish_disabled = finish && @runner.incomplete_visible_steps.any?

          div(class: "pu-wizard-nav flex items-center justify-between gap-3 border-t border-[var(--pu-border)] bg-[var(--pu-surface-alt)] px-6 py-4 sm:px-8") do
            div(class: "flex items-center gap-2") do
              nav_button("Back", direction: "back", style: "pu-btn-outline", embedded:) if show_back?
              nav_button("Cancel", direction: "cancel", style: "pu-btn-ghost", embedded:)
            end
            div(class: "flex items-center gap-2") do
              if finish
                nav_button("Finish", direction: "next", style: "pu-btn-primary", embedded:, disabled: finish_disabled, name: "finish")
              else
                render_forward_buttons(embedded:)
              end
            end
          end
        end

        # The forward action(s) on a non-review step. The primary button reads
        # "Save & continue" when revisiting an already-submitted step (the edit is
        # persisted), else "Next". Once EVERY visible step is complete — the
        # post-completion edit case — a "Save & review" shortcut appears that stages
        # this step and jumps straight to review (the primary action then; "Save &
        # continue" steps to the next step as the secondary). The shortcut is hidden
        # when the next step already IS review (it would be redundant).
        def render_forward_buttons(embedded:)
          step = @runner.current_step
          continue_label = @runner.submitted?(step) ? "Save & continue" : "Next"

          if review_shortcut?(step)
            nav_button(continue_label, direction: "next", style: "pu-btn-outline", embedded:, name: "next")
            nav_button("Save & review", direction: "next", style: "pu-btn-primary", embedded:, name: "save_review", goto: "review")
          else
            nav_button(continue_label, direction: "next", style: "pu-btn-primary", embedded:, name: "next")
          end
        end

        # Whether to offer the "Save & review" shortcut: every visible step is
        # complete AND the next visible step isn't already the review (so the
        # shortcut lands somewhere the plain Next wouldn't).
        def review_shortcut?(step)
          return false unless @runner.incomplete_visible_steps.empty?

          path = @runner.visible_path
          idx = path.index { |s| s.key.to_s == step.key.to_s }
          next_step = path[idx + 1] if idx
          next_step && !next_step.review?
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
        def nav_button(label, direction:, style:, embedded:, disabled: false, name: nil, goto: nil)
          data = {wizard_nav: name || direction}
          # Back/Cancel post WITHOUT the step's field values, so any unsaved edits
          # on the current step are discarded. Mark them so the (already-attached)
          # dirty-form-guard warns before that loss. Next/Finish save, so no guard.
          data["dirty-form-guard-leave"] = leave_warning(direction) if %w[back cancel].include?(direction)

          # Finish (→ the created resource) and Cancel (→ out of the flow) redirect
          # AWAY from the wizard, to a page with a different structure. The layout
          # opts into Turbo morphing (`turbo-refresh-method: morph`), and these post
          # to the current URL, so Turbo treats the result as a page refresh and
          # morphs the destination INTO the wizard DOM (nesting it) instead of
          # replacing the page. Opt these submitters out of Turbo so they do a clean
          # full navigation. In-wizard Next/Back stay on Turbo (same structure →
          # morph is correct and smooth).
          data["turbo"] = "false" if exits_wizard?(name, direction)

          if embedded
            button(
              type: :submit, name: "_direction", value: direction,
              class: "pu-btn pu-btn-md #{style}", disabled: disabled || nil,
              data:
            ) { label }
          elsif direction == "next"
            # Next submits the step form (which holds the inputs). The page's nav
            # Next button is associated with the wizard form via the `form` attr.
            # A `goto` button instead carries `_goto` (and NO `_direction`, since only
            # the clicked button's name/value is submitted) — a blank `_direction`
            # still routes to advance, which honors the `goto` cursor override.
            btn_name, btn_value = goto ? ["_goto", goto] : ["_direction", "next"]
            button(
              type: :submit, form: "wizard-form", name: btn_name, value: btn_value,
              class: "pu-btn pu-btn-md #{style}", disabled: disabled || nil,
              data:
            ) { label }
          else
            # Back/Cancel post on their own — no field validation, so an independent
            # mini-form carrying only _direction is correct. Cancel exits the wizard,
            # so the form itself opts out of Turbo (the submit button alone isn't the
            # navigating element here — the form is).
            form_data = exits_wizard?(name, direction) ? {turbo: "false"} : {}
            form(action: @step_url, method: "post", class: "inline", data: form_data) do
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

        # Whether a nav control redirects OUT of the wizard (Finish → resource,
        # Cancel → exit), as opposed to in-wizard navigation (Next/Back). Such
        # controls must do a full navigation, not a Turbo morph (see {#nav_button}).
        def exits_wizard?(name, direction)
          name.to_s == "finish" || direction == "cancel"
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

        # Errors from a failed finalize (`execute`), surfaced on the review step —
        # which has no field form to attach them to. Shows ALL messages, not just
        # `:base`: a field-level error from `execute` (e.g. {name: ["has already
        # been taken"]} when a uniqueness check fails) would otherwise be dropped,
        # leaving Finish to silently re-render unchanged ("nothing happens").
        def render_review_errors
          messages = review_error_messages
          return if messages.empty?

          div(class: "rounded-lg border border-danger-200 bg-danger-50 dark:border-danger-800 dark:bg-danger-950/30 p-4 mb-4", role: "alert") do
            ul(class: "space-y-1") do
              messages.each { |m| li(class: "text-sm text-danger-700 dark:text-danger-400") { m } }
            end
          end
        end

        # Every finalize error as a full sentence: a `:base` error renders verbatim;
        # a field error is prefixed with its humanized attribute, mirroring Rails'
        # `full_messages` — so {name: ["has already been taken"]} → "Name has
        # already been taken".
        def review_error_messages
          @errors.flat_map do |attr, msgs|
            base = attr.to_s == "base"
            Array(msgs).map { |m| base ? m : "#{attr.to_s.humanize} #{m}" }
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
