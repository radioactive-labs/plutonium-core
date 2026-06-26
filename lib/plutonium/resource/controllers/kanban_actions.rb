# frozen_string_literal: true

module Plutonium
  module Resource
    module Controllers
      # Provides the per-column lazy turbo-frame endpoint for kanban boards.
      #
      # When a request hits the index action with view=kanban AND column=<key>,
      # this concern intercepts via a before_action, renders ONLY the column's
      # frame body (Plutonium::UI::Kanban::Column), and halts the normal
      # index render. Unknown/absent column keys produce an empty frame body.
      #
      # Seam for Task 10 (full board shell):
      #   This concern only fires when params[:column] is present. Task 10
      #   should handle the view=kanban case WITHOUT params[:column] — either
      #   via a separate branch in the same before_action or by overriding
      #   render_default_content in Plutonium::UI::Page::Index to add a
      #   :kanban case. Neither approach will conflict with this concern.
      module KanbanActions
        extend ActiveSupport::Concern

        included do
          # Intercept index when view=kanban + column=<key> is present.
          # Runs BEFORE setup_index_action! so no wasteful pagination query.
          before_action :maybe_render_kanban_column, only: :index
        end

        private

        # Memoized kanban board compiled from the definition's kanban block.
        def current_kanban_board
          @current_kanban_board ||= Plutonium::Kanban::DSL.build(&current_definition.defined_kanban_block)
        end

        # Authorized + query-applied UN-paginated relation.
        #
        # Mirrors filtered_resource_collection from IndexAction::CrudActions but
        # without the Pagy pagination step. Reuses the same query pipeline so
        # search, filters, scopes, and tenant/parent scoping all apply.
        def kanban_base_relation
          @kanban_base_relation ||= begin
            query_params = current_definition
              .query_form.new(nil, query_object: current_query_object, page_size: nil)
              .extract_input(params, view_context:)[:q]

            base_query = current_authorized_scope
            current_query_object.apply(base_query, query_params, context: self)
          end
        end

        # Intercepts the index action when view=kanban + column= is present.
        # Renders only the turbo-frame body for the requested column and halts.
        def maybe_render_kanban_column
          return unless params[:view] == "kanban" && params[:column].present?
          return unless current_definition.defined_kanban_block

          # Fulfill authorization requirements so after_action verifiers pass.
          authorize_current! resource_class

          board = current_kanban_board
          column_key = params[:column].to_sym
          context = Plutonium::Kanban::Context.new(view_context)

          # Build the authorized, query-applied relation then group it.
          # Calling kanban_base_relation also satisfies verify_current_authorized_scope.
          groups = Plutonium::Kanban::Grouping.call(
            board: board,
            relation: kanban_base_relation,
            context: context
          )

          entry = groups.find { |g| g[:column].key == column_key }

          if entry
            # resource_fields is the policy-permitted attribute list, used by
            # Grid::Card to gate slot visibility. Slot mapping comes from
            # resource_definition.defined_grid_fields (or board.card_fields
            # will be applied at Task 10 time via a definition decorator).
            column_component = Plutonium::UI::Kanban::Column.new(
              column: entry[:column],
              cards: entry[:cards],
              total: entry[:total],
              per_column: board.per_column,
              resource_definition: current_definition,
              resource_fields: presentable_attributes
            )
            html = view_context.render(column_component)
          else
            # Unknown column key — render an empty frame body, no crash.
            html = ""
          end

          render html: html.html_safe, layout: false
        end
      end
    end
  end
end
