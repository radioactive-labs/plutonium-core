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
        # @param visited   [Array<String>] visited (reached) step keys.
        # @param complete  [Array<String>] keys of steps that are actually complete
        #   (submitted AND valid) — distinct from `visited`. A step can be reached
        #   (e.g. the cursor landed on a branch step) without being completed.
        # @param navigation [Symbol] :linear or :free.
        # @param step_url   [Proc] step_key → GET url.
        def initialize(steps:, current:, visited:, navigation:, step_url:, complete: [])
          @steps = steps
          @current = current
          @visited = visited.map(&:to_s)
          @complete = complete.map(&:to_s).to_set
          @navigation = navigation
          @step_url = step_url
        end

        def view_template
          nav(class: "pu-wizard-stepper mb-7", aria_label: "Progress") do
            ol(class: "pu-wizard-steps") do
              @steps.each_with_index do |step, index|
                render_step(step, index)
              end
            end
          end
        end

        private

        # One step: a numbered node on the connector track + a label beneath. Both
        # are wrapped in a link when the step is reachable (CSS draws the track,
        # node states, and the done check via [data-state]).
        def render_step(step, index)
          state = step_state(step)
          # `data-terminal` marks the review node so the CSS suppresses the
          # "completed" checkmark for it — it's the finish flag, never a done-check.
          li(data: {state:, wizard_stepper_state: state, terminal: step.review? ? "true" : nil}) do
            if clickable?(step, state)
              a(href: @step_url.call(step.key), class: "pu-step-link",
                aria_current: (state == :current) ? "step" : nil) do
                render_node(step, index)
                span(class: "pu-step-label") { step.label.to_s }
              end
            else
              span(class: "pu-step-link") do
                render_node(step, index)
                span(class: "pu-step-label",
                  aria_current: (state == :current) ? "step" : nil) { step.label.to_s }
              end
            end
          end
        end

        # The node: a numbered badge for a real step. The terminal review step isn't
        # a numbered step (it's the "finish line"), so it shows a flag icon instead —
        # no step number, here or in the card header (see Page::Wizard).
        def render_node(step, index)
          span(class: "pu-step-node") do
            if step.review?
              render_review_icon
            else
              # Review is always last, so a real step's index in the full path is
              # also its position among real steps → a clean 1-based badge.
              span(class: "pu-step-number") { (index + 1).to_s }
            end
          end
        end

        def render_review_icon
          render Phlex::TablerIcons::Flag.new(class: "pu-step-flag w-4 h-4")
        end

        # A step's visual state. `:completed` (the done-check) means actually
        # complete — submitted AND valid — NOT merely reached: a branch step the
        # cursor landed on but that was never submitted (or is now invalid) is
        # `:incomplete`, so the rail never claims a step is done when the review
        # still lists it under "needs attention". The terminal review node is the
        # finish flag, so it reads `:completed` once reached (its check is suppressed
        # by `data-terminal`).
        def step_state(step)
          return :current if step.key.to_s == @current&.key.to_s
          if @visited.include?(step.key.to_s)
            return :completed if step.review? || @complete.include?(step.key.to_s)
            return :incomplete
          end
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
