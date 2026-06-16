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
              # Highlight the connector once the step it trails is done, so the
              # stepper reads as filled-up-to-here progress.
              fill = (state == :completed) ? "bg-primary-500 dark:bg-primary-400" : "bg-[var(--pu-border)]"
              span(class: "mx-2 h-px w-6 #{fill}", aria_hidden: "true")
            end
          end
        end

        def render_marker(index, state)
          classes = case state
          when :current
            "bg-primary-600 text-white border-primary-600 shadow-sm"
          when :completed
            "bg-primary-50 text-primary-700 border-primary-500 dark:bg-primary-900/40 dark:text-primary-300 dark:border-primary-500"
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

        # Which step headers link. Mirrors the engine's `Runner#go_to` reachability
        # so the stepper never offers (or withholds) a jump the engine would reject:
        #
        #   - the current step never links to itself;
        #   - the terminal review step links once the flow has started (any step
        #     visited) — it's never itself "visited" (you Finish from it, you don't
        #     advance past it), so without this it would be permanently unclickable,
        #     stranding a user who navigated back from it;
        #   - every other step links once visited. Forward jumps to unvisited steps
        #     stay disallowed.
        def clickable?(step, state)
          return false if state == :current
          return @visited.any? if step.review?
          @visited.include?(step.key.to_s)
        end
      end
    end
  end
end
