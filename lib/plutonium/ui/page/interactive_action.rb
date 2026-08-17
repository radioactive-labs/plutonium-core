# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class InteractiveAction < Base
        include Phlex::Rails::Helpers::TurboFrameTag

        private

        def page_title
          current_interactive_action.label || super
        end

        def page_description
          current_interactive_action.description || super
        end

        def render_default_content
          if in_modal?
            modal_class = Plutonium::UI::Modal::Base.class_for_mode(
              current_interactive_action.modal_mode(current_definition)
            )

            render modal_class.new(
              title: page_title,
              description: page_description,
              size: current_interactive_action.modal_size(current_definition),
              # The action's own GET path renders the standalone branch below,
              # and lands in a NEW TAB, so the modal keeps whatever has already
              # been typed into it. Submitting from there carries no
              # `return_to`, which is exactly the case the controller handles by
              # computing the destination itself (see Form::Resource
              # #render_actions).
              open_full_url: request.path
            ) do
              render_interactive_action_form
            end
          else
            div(class: "pb-20") { render_interactive_action_form }
          end
        end

        # Renders the interaction's form inside the modal/page chrome.
        # Extracted as a seam so subclasses (e.g. the kanban drop-move page)
        # can swap in a form that posts elsewhere and carries extra context
        # without duplicating the modal chrome above.
        def render_interactive_action_form
          render partial(interactive_action_form_partial)
        end

        def interactive_action_form_partial = "interactive_action_form"

        def page_type = :interactive_action_page
      end
    end
  end
end
