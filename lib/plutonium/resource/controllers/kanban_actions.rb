# frozen_string_literal: true

module Plutonium
  module Resource
    module Controllers
      # Provides kanban-board endpoints for resources that declare a kanban block.
      #
      # ## Lazy column frame endpoint (Task 6)
      #
      # When a request hits the index action with view=kanban AND column=<key>,
      # this concern intercepts via a before_action, renders ONLY the column's
      # frame body (Plutonium::UI::Kanban::Column), and halts the normal
      # index render. Unknown/absent column keys produce an empty frame body.
      #
      # ## Kanban move action (Task 7)
      #
      # POST <member>/kanban_move with params {from_column:, to_column:, to_index:}
      # moves the member record to a new column and/or position.  The action:
      #
      #   1. Authorizes via kanban_move? policy predicate.
      #   2. Validates the drop (accepts? + locked?).
      #   3. Enforces the destination WIP limit (cross-column drops only).
      #   4. Applies the column's on_drop callback (Symbol or 1-arg Proc).
      #   5. Repositions within the destination column via position_config.
      #   6. Responds with Turbo Stream updates for the from + to column frames.
      #      On rejection responds 422 and re-renders the unchanged source frame
      #      so the Stimulus controller can snap the card back.
      #
      # Seam for Task 10 (full board shell):
      #   maybe_render_kanban_column only fires when params[:column] is present.
      #   Task 10 should handle the view=kanban case WITHOUT params[:column].
      module KanbanActions
        extend ActiveSupport::Concern

        included do
          # Intercept index when view=kanban + column=<key> is present.
          # Runs BEFORE setup_index_action! so no wasteful pagination query.
          before_action :maybe_render_kanban_column, only: :index

          # Pre-fill the new form with the column's seed attributes when the
          # user clicks "+ Add" on a kanban column (kanban_column= query param).
          before_action :apply_kanban_column_defaults!, only: :new

          # Exposed to views/partials so _resource_kanban.html.erb can call it.
          helper_method :build_kanban_board_shell
        end

        # POST <member>/kanban_move
        #
        # Params:
        #   from_column [String] source column key
        #   to_column   [String] destination column key
        #   to_index    [Integer] 0-based insertion index within destination
        #
        # Responds with Turbo Streams updating the from + to column frames on
        # success, or 422 re-rendering the unchanged source frame on rejection.
        def kanban_move
          # Find record within authorized scope (satisfies scope verifier).
          record = kanban_base_relation.find(params[:id])
          # Check move permission (satisfies authorize verifier).
          authorize_current! record, to: :kanban_move?

          unless current_definition.defined_kanban_block
            head :not_found
            return
          end

          board   = current_kanban_board
          columns = Plutonium::Kanban::Grouping.resolve_columns(board, kanban_context)
          from    = columns.find { |c| c.key.to_s == params[:from_column].to_s }
          to      = columns.find { |c| c.key.to_s == params[:to_column].to_s }

          unless from && to && to.accepts?(from.key) && !from.locked?
            return render_kanban_rejection(params[:from_column])
          end

          # Build the destination card list excluding the moved record so the
          # neighbor computation and WIP count are correct in all cases
          # (cross-column, same-column reorder, record already in destination).
          dest_scoped = Plutonium::Kanban::Grouping.apply_scope(kanban_base_relation, to.scope)
          dest_cards  = board.position_config.order(dest_scoped).where.not(id: record.id).to_a
          to_index    = params[:to_index].to_i

          # WIP limit only applies to cross-column drops (reordering within the
          # same column does not change its cardinality). This is a
          # pre-transaction read — benign TOCTOU: two concurrent moves could
          # momentarily push the column one over wip. Acceptable for a UI guard.
          if to.wip && from.key != to.key && dest_cards.size + 1 > to.wip
            return render_kanban_rejection(params[:from_column])
          end

          prev_record = to_index > 0 ? dest_cards[to_index - 1] : nil
          next_record = dest_cards[to_index]

          ActiveRecord::Base.transaction do
            # Apply on_drop:
            #   Symbol → record.public_send(sym) (named method on the record)
            #   Proc   → evaluated with self = kanban_context (delegates to
            #            view_context so `current_user` etc. work as bare calls)
            #            and the record as the single block arg, matching the
            #            public 1-arg DSL form: on_drop: ->(task) { task.status = … }
            if to.on_drop.is_a?(Symbol)
              record.public_send(to.on_drop)
            elsif to.on_drop
              kanban_context.instance_exec(record, &to.on_drop)
            end

            # Persist any in-memory attribute changes from on_drop (on_drop
            # blocks that call update! directly are already saved; this is a
            # safety net for blocks that only assign attributes).
            record.save! if record.changed?

            # Reposition within the destination column.
            # Mode A delegates to record.reposition! (calls update! for position).
            # Mode B calls the user-supplied block.
            # Mode C is a no-op (no ordering; position unchanged).
            board.position_config.reposition!(
              record:,
              column: to.key,
              prev_record:,
              next_record:,
              index: to_index
            )

            # Final save covers Mode C where reposition! is a no-op but on_drop
            # only assigned in memory, or any other unsaved attribute changes.
            record.save! if record.changed?
          end

          respond_to do |format|
            format.turbo_stream do
              streams = [turbo_stream.update("kanban-col-#{from.key}", render_kanban_column_html(from))]
              if from.key != to.key
                streams << turbo_stream.update("kanban-col-#{to.key}", render_kanban_column_html(to))
              end
              render turbo_stream: streams
            end
          end
        end

        private

        # Builds the kanban board shell component for the index page.
        #
        # Used by the _resource_kanban partial (Task 10). The shell renders one
        # lazy turbo-frame per column — no card data is fetched here; the frames
        # load card bodies on demand via the Task 6 column endpoint.
        #
        # Resolves columns via Grouping.resolve_columns so dynamic boards work
        # identically to static ones. grouped_data has empty card arrays because
        # the shell header only needs the column metadata (label, color, key).
        def build_kanban_board_shell
          board = current_kanban_board
          columns = Plutonium::Kanban::Grouping.resolve_columns(board, kanban_context)
          grouped_data = columns.map { |col| {column: col, cards: [], total: 0} }
          Plutonium::UI::Kanban::Resource.new(
            board:,
            grouped_data:,
            resource_definition: current_definition,
            resource_fields: permitted_attributes_for("index")
          )
        end

        # Memoized kanban board. Prefers the board precompiled at definition
        # class-load time (Definition::IndexViews.kanban); falls back to building
        # from the block for safety and dynamic edge cases.
        def current_kanban_board
          @current_kanban_board ||= current_definition.defined_kanban_board ||
            Plutonium::Kanban::DSL.build(&current_definition.defined_kanban_block)
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

          # Resolve only the requested column rather than grouping the whole
          # board: Grouping.call would scope+count+limit every column (~2 queries
          # each) on every lazy frame request. We compare keys as strings to
          # avoid interning arbitrary request input into symbols.
          columns = Plutonium::Kanban::Grouping.resolve_columns(board, kanban_context)
          column = columns.find { |c| c.key.to_s == params[:column] }

          # Unknown column key — render an empty frame body, no crash.
          # kanban_base_relation is referenced so verify_current_authorized_scope
          # still passes even on the empty path.
          unless column
            kanban_base_relation
            return render(html: "", layout: false)
          end

          render html: render_kanban_column_html(column), layout: false
        end

        # Renders a single column component to an HTML-safe string.
        #
        # Accepts either a Plutonium::Kanban::Column object or a column key
        # (String/Symbol). Returns an empty SafeBuffer for unknown keys.
        def render_kanban_column_html(column_or_key)
          board = current_kanban_board

          column = if column_or_key.is_a?(Plutonium::Kanban::Column)
            column_or_key
          else
            columns = Plutonium::Kanban::Grouping.resolve_columns(board, kanban_context)
            columns.find { |c| c.key.to_s == column_or_key.to_s }
          end

          return "".html_safe unless column

          scoped  = Plutonium::Kanban::Grouping.apply_scope(kanban_base_relation, column.scope)
          ordered = board.position_config.order(scoped)

          if board.per_column
            total = ordered.count
            cards = ordered.limit(board.per_column).to_a
          else
            cards = ordered.to_a
            total = cards.size
          end

          # Cards are a read-only display, so resolve the visible fields from the
          # index/read attribute set rather than the action name. This keeps the
          # move action from needing a `permitted_attributes_for_kanban_move`
          # method — kanban deliberately has no permitted-attributes concept.
          column_action_data = column.actions.map do |col_action|
            {action: col_action, ids: kanban_column_action_ids(column, on: col_action.on)}
          end

          column_add_url = if column.add? && current_policy.allowed_to?(:create?)
            resource_url_for(resource_class, action: :new, kanban_column: column.key)
          end

          component = Plutonium::UI::Kanban::Column.new(
            column:,
            cards:,
            total:,
            per_column: board.per_column,
            resource_definition: current_definition,
            resource_fields: permitted_attributes_for("index"),
            column_action_data:,
            column_add_url:
          )
          view_context.render(component).html_safe
        end

        # Returns the primary-key ids for a column action based on `on:` scope.
        #
        # on: :all     → ids of ALL records matching the column scope within
        #                 the current kanban_base_relation (ignores per_column).
        # on: :visible → ids of the rendered, per_column-capped subset (applies
        #                 position ordering + limit, then plucks ids).
        #
        # Any other value falls back to :all behaviour.
        def kanban_column_action_ids(column, on:)
          scoped = Plutonium::Kanban::Grouping.apply_scope(kanban_base_relation, column.scope)
          case on.to_sym
          when :visible
            board = current_kanban_board
            ordered = board.position_config.order(scoped)
            limited = board.per_column ? ordered.limit(board.per_column) : ordered
            limited.pluck(resource_class.primary_key)
          else # :all and any unknown value
            scoped.pluck(resource_class.primary_key)
          end
        end

        # Injects the column's seed attributes into params so the new form
        # pre-fills the grouping attribute (e.g. status="todo").
        #
        # Triggered by the kanban_column= query param that the "+ Add" link
        # carries. The seed is extracted by running a DRY-RUN of on_drop against
        # a sentinel record whose save/update! methods are intercepted to prevent
        # any DB write. The resulting attribute changes are merged into the
        # resource params so maybe_apply_submitted_resource_params! sees them and
        # pre-populates @resource_record before the form renders.
        def apply_kanban_column_defaults!
          return unless params[:kanban_column].present?
          return unless current_definition.defined_kanban_block

          board = current_kanban_board
          columns = Plutonium::Kanban::Grouping.resolve_columns(board, kanban_context)
          column = columns.find { |c| c.key.to_s == params[:kanban_column].to_s }
          return unless column&.add?

          # A raising on_drop must not 500 the new form — degrade to an unseeded
          # form so the user can still create the record (and set the grouping
          # field manually).
          seed_attrs = begin
            kanban_column_on_drop_seed(column)
          rescue => e
            Rails.logger.warn { "kanban quick-add seed failed for column #{column.key}: #{e.message}" }
            return
          end
          return if seed_attrs.blank?

          # Inject into params (indifferent access — string key is fine).
          # Use ||= so an explicit user-provided value in the URL is preserved.
          params[resource_param_key] ||= ActionController::Parameters.new({})
          seed_attrs.stringify_keys.each { |k, v| params[resource_param_key][k] ||= v }
        end

        # Runs on_drop against a sentinel record that intercepts save/update!
        # calls so no row is written to the DB. Returns the attribute changes
        # the on_drop block would have applied (e.g. {"status" => "todo"}).
        #
        # NOTE: this only stubs save/save!/update/update! on the sentinel record.
        # An on_drop that has external side effects (enqueuing jobs, API calls,
        # touching OTHER records) would fire those side effects on every "+ Add"
        # click, since they bypass the stubbed methods. This is acceptable for
        # the common `attr = value` / `update!(attr: value)` pattern but is a
        # footgun for exotic on_drop callbacks.
        def kanban_column_on_drop_seed(column)
          return {} unless column.on_drop

          seed = resource_class.new
          seed.define_singleton_method(:update!) { |attrs = {}| assign_attributes(attrs); self }
          seed.define_singleton_method(:update)  { |attrs = {}| assign_attributes(attrs); true }
          seed.define_singleton_method(:save!)   { |**| true }
          seed.define_singleton_method(:save)    { |**| true }

          if column.on_drop.is_a?(Symbol)
            seed.public_send(column.on_drop)
          else
            kanban_context.instance_exec(seed, &column.on_drop)
          end

          seed.changes.transform_values { |(_, new_val)| new_val }
        end

        # Renders a 422 turbo stream response that re-renders the source column
        # unchanged, allowing the Stimulus drag controller to snap the card back.
        def render_kanban_rejection(from_key)
          render(
            turbo_stream: turbo_stream.update(
              "kanban-col-#{from_key}",
              render_kanban_column_html(from_key.to_s)
            ),
            status: :unprocessable_content
          )
        end

        # Evaluation context for dynamic `columns do…end` blocks — delegates to
        # the view_context so the block can call current_user, params, etc.
        def kanban_context
          @kanban_context ||= Plutonium::Kanban::Context.new(view_context)
        end
      end
    end
  end
end
