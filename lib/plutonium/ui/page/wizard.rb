# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      # MINIMAL wizard step page (§7). Task 6 replaces this with the real
      # stepper/review UI and the full form pipeline (form_layout, typed inputs,
      # `using:` imports, repeater rehydration).
      #
      # For now it renders just enough to drive the flow end-to-end: the current
      # step's fields as plain inputs (named `wizard[<attr>]`, seeded from staged
      # data), any errors, and Back / Next / Cancel buttons carrying `_direction`.
      class Wizard < Plutonium::UI::Component::Base
        def initialize(runner:, step_url:, errors: nil)
          @runner = runner
          @step_url = step_url
          @errors = errors || {}
        end

        def view_template
          step = @runner.current_step

          article(class: "pu-wizard", data: {controller: "wizard"}) do
            render_stepper
            h1 { step&.label.to_s }
            render_errors

            form(action: @step_url, method: "post", id: "wizard-form") do
              # Method/forgery tokens are injected by the layout's form helpers in
              # the real UI; for the minimal page we POST via a plain form and rely
              # on the test harness. A hidden _direction defaults to "next".
              input(type: "hidden", name: "_direction", value: "next", data: {wizard_target: "direction"})

              render_step_fields(step) if step && !step.review?
              render_review(step) if step&.review?

              render_nav_buttons
            end
          end
        end

        private

        def render_stepper
          nav(class: "pu-wizard-stepper") do
            ol do
              @runner.visible_path.each do |s|
                current = (s.key == @runner.current_step&.key)
                li(class: current ? "is-current" : nil) { s.label.to_s }
              end
            end
          end
        end

        def render_errors
          return if @errors.blank?

          div(class: "pu-wizard-errors", role: "alert") do
            ul do
              @errors.each do |attr, messages|
                Array(messages).each do |message|
                  li { "#{attr}: #{message}" }
                end
              end
            end
          end
        end

        def render_step_fields(step)
          data = staged_data

          step.attribute_schema.each_key do |name|
            render_text_field(name, data[name.to_s])
          end

          step.structured_inputs.each_key do |name|
            render_text_field(name, data[name.to_s])
          end
        end

        def render_text_field(name, value)
          div(class: "pu-wizard-field") do
            label(for: "wizard_#{name}") { name.to_s.humanize }
            input(
              type: "text",
              id: "wizard_#{name}",
              name: "wizard[#{name}]",
              value: value.to_s
            )
          end
        end

        def render_review(_step)
          section(class: "pu-wizard-review") do
            h2 { "Review" }
            dl do
              staged_data.each do |key, value|
                dt { key.to_s.humanize }
                dd { value.to_s }
              end
            end
          end
        end

        def render_nav_buttons
          div(class: "pu-wizard-nav") do
            button(type: "submit", name: "_direction", value: "back") { "Back" }
            button(type: "submit", name: "_direction", value: "cancel") { "Cancel" }
            button(type: "submit", name: "_direction", value: "next") do
              @runner.current_step&.review? ? "Finish" : "Next"
            end
          end
        end

        def staged_data
          @runner.state.data || {}
        end
      end
    end
  end
end
