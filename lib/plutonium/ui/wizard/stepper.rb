# frozen_string_literal: true

module Plutonium
  module UI
    module Wizard
      # The horizontal step indicator (§7). Renders the visible step path with a
      # completed / current / upcoming state per step. Navigation mode gates which
      # steps are clickable:
      #
      #   - :linear → only already-visited steps link back (no forward jumps).
      #   - :free   → any visited step links (still no forward jumps to unvisited).
      #
      # Branch-hidden steps are simply absent from `visible_path`, so they never
      # appear here.
      class Stepper < Plutonium::UI::Component::Base
        # @param steps     [Array<Step>] the visible path.
        # @param current   [Step] the current step.
        # @param visited   [Array<String>] visited step keys.
        # @param navigation [Symbol] :linear or :free.
        # @param step_url   [Proc] step_key → GET url.
        def initialize(steps:, current:, visited:, navigation:, step_url:)
          @steps = steps
          @current = current
          @visited = visited.map(&:to_s)
          @navigation = navigation
          @step_url = step_url
        end

        def view_template
          nav(class: "pu-wizard-stepper mb-8", aria_label: "Progress") do
            ol(class: "flex flex-wrap items-center gap-x-2 gap-y-3") do
              @steps.each_with_index do |step, index|
                render_step(step, index)
              end
            end
          end
        end

        private

        def render_step(step, index)
          state = step_state(step)
          li(class: "flex items-center gap-2") do
            render_marker(index, state)
            render_label(step, state)
            unless index == @steps.length - 1
              span(class: "mx-2 h-px w-6 bg-[var(--pu-border)]", aria_hidden: "true")
            end
          end
        end

        def render_marker(index, state)
          classes = case state
          when :current
            "bg-[var(--pu-primary)] text-white border-[var(--pu-primary)]"
          when :completed
            "bg-[var(--pu-primary)]/10 text-[var(--pu-primary)] border-[var(--pu-primary)]"
          else
            "bg-[var(--pu-surface)] text-[var(--pu-text-muted)] border-[var(--pu-border)]"
          end
          span(
            class: "flex h-7 w-7 shrink-0 items-center justify-center rounded-full border text-xs font-semibold #{classes}",
            data: {wizard_stepper_state: state}
          ) { (index + 1).to_s }
        end

        def render_label(step, state)
          text_class =
            (state == :current) ? "text-[var(--pu-text)] font-semibold" : "text-[var(--pu-text-muted)]"

          if clickable?(step, state)
            a(
              href: @step_url.call(step.key),
              class: "text-sm #{text_class} hover:underline",
              aria_current: (state == :current) ? "step" : nil
            ) { step.label.to_s }
          else
            span(
              class: "text-sm #{text_class}",
              aria_current: (state == :current) ? "step" : nil
            ) { step.label.to_s }
          end
        end

        def step_state(step)
          return :current if step.key.to_s == @current&.key.to_s
          return :completed if @visited.include?(step.key.to_s)
          :upcoming
        end

        # Only visited (non-current) steps are reachable. Forward jumps to unvisited
        # steps are never allowed; mode only differs in nuance (both gate on
        # visited here, since the path is linear by construction).
        def clickable?(step, state)
          return false if state == :current
          @visited.include?(step.key.to_s)
        end
      end
    end
  end
end
