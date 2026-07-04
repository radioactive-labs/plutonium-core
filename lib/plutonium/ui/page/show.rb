# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Show < Base
        private

        def page_title
          current_definition.show_page_title || super || display_name_of(resource_record!)
        end

        def page_description
          current_definition.show_page_description || super
        end

        def page_actions
          super || current_definition.defined_actions.values.select { |a| a.record_action? && !a.kanban_drop? && a.permitted_by?(current_policy) && a.condition_met?(view_context, record: resource_record!) }
        end

        def render_default_content
          # When the show request arrives via a modal frame (e.g. a kanban card
          # with `show_in :modal`), wrap the details in the modal chrome — the
          # same path New/Edit use for their forms. The aside is dropped in the
          # modal: a slideover/centered dialog has no room for a side rail.
          return render_modal_details if in_modal?

          if aside_present?
            div(class: "grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_240px] gap-6") do
              div { render partial("resource_details") }
              aside(class: "hidden lg:block") { render_aside }
            end
          else
            render partial("resource_details")
          end
        end

        # The show page is ALWAYS a centered dialog when shown in a modal —
        # deliberately not the definition's modal_mode (which styles :new/:edit
        # as a slideover by default). A centered dialog reads as a focused
        # "detail card" and leaves a launching board/table visible around it.
        # `open_full_url` is the current show URL (request.path is the show
        # route here), letting the user pop the record out to its full page.
        def render_modal_details
          render Plutonium::UI::Modal::Centered.new(
            title: page_title,
            description: page_description,
            size: :lg,
            open_full_url: request.path
          ) do
            # The modal body owns no padding — content provides its own (the
            # form uses this same padded, scrollable region). Without it the
            # detail cards sit flush against the modal edges.
            div(class: "flex-1 min-h-0 overflow-y-auto px-6 py-5") do
              render partial("resource_details")
            end
          end
        end

        def page_type = :show_page
      end
    end
  end
end
