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

        # Tags board-bound redirects with kanban_reload=1 so the permanent board
        # refreshes its cached column frames on arrival (see #kanban_reload_url).
        # Wraps ALL three redirect helpers — create/update (after_submit), destroy
        # (after_destroy), and interactive record/resource/bulk actions
        # (after_action_on). PREPENDED, not a plain override: after_action_on
        # lives in InteractiveActions, which is included AFTER this concern, so a
        # normal override here would be shadowed. Prepending wins regardless of
        # include order, and `super` still reaches the real implementation.
        module ReloadRedirects
          def redirect_url_after_submit
            kanban_reload_url(super)
          end

          def redirect_url_after_destroy
            kanban_reload_url(super)
          end

          def redirect_url_after_action_on(*)
            kanban_reload_url(super)
          end
        end

        included do
          prepend ReloadRedirects

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

          board = current_kanban_board
          columns = Plutonium::Kanban::Grouping.resolve_columns(board, kanban_context)
          from = columns.find { |c| c.key.to_s == params[:from_column].to_s }
          to = columns.find { |c| c.key.to_s == params[:to_column].to_s }

          # accepts_record? evaluates Proc accepts: against the actual record
          # (returning the Proc's boolean result) while delegating to accepts?
          # semantics for true/false/Array values.  This is the server-side
          # authority; the client-side data-kanban-accepts attribute (which
          # treats Proc as "all") is only a drop-hint.
          unless from && to&.accepts_record?(record, from.key) && !from.locked?
            reason =
              if from&.locked?
                "Cards can't be moved out of “#{from.label}”."
              elsif to
                "Cards can't be moved into “#{to.label}”."
              else
                "This card can't be moved there."
              end
            return render_kanban_rejection(params[:from_column], reason:)
          end

          # Build the destination card list excluding the moved record so the
          # neighbor computation and WIP count are correct in all cases
          # (cross-column, same-column reorder, record already in destination).
          dest_scoped = Plutonium::Kanban::Grouping.apply_scope(kanban_base_relation, to.scope)
          dest_cards = board.position_config.order(dest_scoped).where.not(id: record.id).to_a
          to_index = params[:to_index].to_i

          # WIP limit only applies to cross-column drops (reordering within the
          # same column does not change its cardinality). This is a
          # pre-transaction read — benign TOCTOU: two concurrent moves could
          # momentarily push the column one over wip. Acceptable for a UI guard.
          if to.wip && from.key != to.key && dest_cards.size + 1 > to.wip
            return render_kanban_rejection(
              params[:from_column],
              reason: "“#{to.label}” is at its WIP limit (#{to.wip})."
            )
          end

          prev_record = (to_index > 0) ? dest_cards[to_index - 1] : nil
          next_record = dest_cards[to_index]

          # Holds the drop_interaction outcome (when the destination declares
          # one) so the post-transaction branch can distinguish a rolled-back
          # failure from a successful atomic commit.
          outcome = nil

          # A same-column reorder (from.key == to.key) changes only rank, not
          # membership, so it runs ONLY the positioning code — no on_drop, no
          # drop_interaction. Both on_drop (the membership write) and
          # drop_interaction (the transition) represent ENTERING a column; neither
          # should fire when the card is already in it. Task 6 (client) must mirror
          # this: a same-column drop posts a plain reposition and opens no modal.
          cross_column = from.key != to.key
          run_drop_interaction = to.drop_interaction? && cross_column

          # Authorize the transition BEFORE opening the transaction — hoisted out
          # so a denied move can't leave a throwaway on_drop write on the 403
          # path. Bind the drop_interaction's auto-registered hidden record action
          # (so interaction_params / build_interactive_record_action_interaction
          # resolve it) and reuse the already-loaded record as resource_record!
          # (param-extraction subject + form URL) — no re-query, no divergent copy.
          if run_drop_interaction
            params[:interactive_action] = to.drop_interaction_key
            @resource_record = record
            authorize_current! record, to: :"#{to.drop_interaction_key}?"
          end

          ActiveRecord::Base.transaction do
            # (1) Apply on_drop — the membership write, CROSS-column moves only.
            # A same-column reorder skips this (see cross_column above) and only
            # repositions; on_drop represents entering a new column.
            #   Symbol → record.public_send(sym) (named method on the record)
            #   Proc   → evaluated with self = kanban_context (delegates to
            #            view_context so `current_user` etc. work as bare calls)
            #            and the record as the single block arg, matching the
            #            public 1-arg DSL form: on_drop: ->(task) { task.status = … }
            if cross_column
              if to.on_drop.is_a?(Symbol)
                record.public_send(to.on_drop)
              elsif to.on_drop
                kanban_context.instance_exec(record, &to.on_drop)
              end

              # Persist any in-memory attribute changes from on_drop (on_drop
              # blocks that call update! directly are already saved; this is a
              # safety net for blocks that only assign attributes).
              record.save! if record.changed?
            end

            # (2) Drop interaction — runs against the SAME record instance,
            # atomic with the move. Only fires on a CROSS-column move (entering a
            # new column is the transition the interaction represents); a
            # same-column reorder skips it (see run_drop_interaction above). The
            # interactive_action binding + @resource_record + authorize were
            # hoisted out above the transaction.
            if run_drop_interaction
              # build_interactive_record_action_interaction renders the action
              # form to EXTRACT its params (structured inputs / choices). It runs
              # INSIDE the transaction on purpose: so a `choices:` proc (or any
              # form logic) sees the post-on_drop record state. Do NOT hoist this
              # out — doing so would change the record state the form is built
              # against and silently alter param-extraction semantics.
              build_interactive_record_action_interaction
              outcome = @interaction.call
              # Interaction validation failed → undo the on_drop write (and any
              # partial execute) so nothing persists. The re-render happens
              # after the transaction so the rollback is fully applied first.
              raise ActiveRecord::Rollback if outcome.failure?
            end

            # (3) Reposition within the destination column.
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

          # Interaction failed → the transaction rolled back. Re-render the SAME
          # modal (422) with the validation errors + the submitted hidden move
          # fields, so the user can correct the input and resubmit the move.
          if run_drop_interaction && outcome&.failure?
            return render :kanban_move_form, formats: [:html], **modal_render_options, status: :unprocessable_content
          end

          respond_to do |format|
            format.turbo_stream do
              # The column-frame updates are what other viewers need to see — this
              # is the shared, broadcastable payload.
              column_streams = [turbo_stream.update("kanban-col-#{from.key}", render_kanban_column_html(from))]
              column_streams << turbo_stream.update("kanban-col-#{to.key}", render_kanban_column_html(to)) if from.key != to.key

              # Broadcast the frame updates to other connected viewers of this
              # board, when realtime broadcasting is enabled. The mover will also
              # receive this broadcast (they are subscribed to the stream too) — but
              # re-rendering the same frames is idempotent, so the double update is
              # harmless. The modal-close stream is deliberately EXCLUDED: only the
              # mover has this modal open, so closing it for everyone would blow
              # away an unrelated modal another viewer might have open.
              if board.realtime?
                Plutonium::Kanban::Broadcaster.broadcast(
                  resource_class: resource_class,
                  scoped_entity: scoped_to_entity? ? current_scoped_entity : nil,
                  content: column_streams.join
                )
              end

              streams = column_streams
              # When the move arrived via the drop-interaction modal (cross-column
              # only), close that modal by emptying the remote-modal frame AND
              # surface the interaction's success message(s) as toast(s). Both are
              # mover-only: only this viewer has the modal open, so they are
              # deliberately EXCLUDED from the realtime broadcast above (appended
              # to `streams`, never to `column_streams`). Plain moves and
              # same-column reorders aren't in a modal, so nothing is appended.
              if run_drop_interaction
                streams += [turbo_stream.update(Plutonium::REMOTE_MODAL_FRAME, "")]
                outcome.messages.each do |msg, type|
                  streams += [turbo_stream.append("kanban-flash", partial: "plutonium/toast",
                    locals: {type: (type == :notice ? :success : type), msg:})]
                end
              end

              render turbo_stream: streams
            end
          end
        end

        # GET <member>/kanban_move_form?from_column=&to_column=&to_index=
        #
        # Renders the drop-interaction modal for a card dropped into a column
        # that declares a `drop_interaction:`. The modal shows the interaction's
        # normal form, but wired to POST to `kanban_move` (Task 4) carrying the
        # move context as hidden fields so the interaction runs AND the card is
        # repositioned in one atomic request.
        def kanban_move_form
          @resource_record = kanban_base_relation.find(params[:id])
          record = @resource_record
          to = kanban_column_for(params[:to_column])

          unless to&.drop_interaction?
            # No interaction to authorize against on this path — the drop is
            # simply invalid — so satisfy the authorize verifier explicitly.
            skip_verify_authorize_current!
            head :unprocessable_content
            return
          end

          authorize_current! record, to: :"#{to.drop_interaction_key}?"

          # Bind the drop_interaction's auto-registered record action as the
          # current interactive action so the modal chrome (title, description,
          # modal mode/size) resolves exactly like a standard record action.
          params[:interactive_action] = to.drop_interaction_key

          @interaction = to.drop_interaction.new(view_context:)
          @interaction.resource = record

          render :kanban_move_form, formats: [:html], **modal_render_options
        end

        private

        # Resolves a kanban column by its key (String/Symbol). Compares keys as
        # strings so arbitrary request input isn't interned into symbols.
        def kanban_column_for(key)
          columns = Plutonium::Kanban::Grouping.resolve_columns(current_kanban_board, kanban_context)
          columns.find { |c| c.key.to_s == key.to_s }
        end

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
          # collapsed: the effective (cookie-resolved) state, so the lazy-frame
          # placeholder renders in the SAME shape the loaded column will — a
          # collapsed column shows a strip from the first paint instead of a full
          # header that then snaps to a strip.
          grouped_data = columns.map do |col|
            {column: col, cards: [], total: 0, collapsed: kanban_effective_collapsed(col)}
          end
          Plutonium::UI::Kanban::Resource.new(
            board:,
            grouped_data:,
            resource_definition: current_definition,
            resource_fields: permitted_attributes_for("index"),
            resource_class: resource_class,
            scoped_entity: scoped_to_entity? ? current_scoped_entity : nil
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

          # The lazy `<turbo-frame id="kanban-col-<key>" src=…>` in the shell
          # requires the response to contain a turbo-frame with the SAME id, or
          # Turbo renders "Content missing". Wrap the column body in that frame.
          # (The move action targets the frame via turbo_stream.update instead,
          # so render_kanban_column_html stays body-only for that path.)
          frame_id = "kanban-col-#{params[:column]}"

          # Unknown column key — render an empty (matching) frame, no crash.
          # kanban_base_relation is referenced so verify_current_authorized_scope
          # still passes even on the empty path.
          unless column
            kanban_base_relation
            empty = view_context.content_tag("turbo-frame", "", id: frame_id)
            return render(html: empty, layout: false)
          end

          framed = view_context.content_tag("turbo-frame", render_kanban_column_html(column), id: frame_id)
          render html: framed, layout: false
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

          scoped = Plutonium::Kanban::Grouping.apply_scope(kanban_base_relation, column.scope)
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
            resource_url_for(resource_class, action: :new, kanban_column: column.key,
              return_to: kanban_board_url)
          end

          component = Plutonium::UI::Kanban::Column.new(
            column:,
            cards:,
            total:,
            per_column: board.per_column,
            resource_definition: current_definition,
            resource_fields: permitted_attributes_for("index"),
            column_action_data:,
            column_add_url:,
            board_url: kanban_board_url,
            card_fields: board.card_fields,
            card_show_frame: kanban_card_show_frame(board),
            collapsed: kanban_effective_collapsed(column)
          )
          view_context.render(component).html_safe
        end

        # The board's own URL — the collection path with view=kanban and any
        # active board query (search / filter / scope), minus the per-column
        # frame param. Used as the quick-add return_to so creating a card returns
        # the user to the board (at their scroll + filters) instead of the new
        # record's show page. Built from resource_url_for rather than request.path
        # because this also runs under the kanban_move POST, whose request path is
        # the member move URL, not the collection path.
        def kanban_board_url
          board_params = request.query_parameters.except("column", "format").merge("view" => "kanban")
          "#{resource_url_for(resource_class)}?#{board_params.to_query}"
        end

        # Tags a board-bound redirect with the one-shot kanban_reload marker (and
        # normalizes it to the FULL board) so a write/action that returns to the
        # permanent board doesn't show stale columns (a new card missing, a
        # deleted/archived one lingering). The kanban Stimulus controller consumes
        # the marker on connect, re-fetches the column frames, and strips it from
        # the URL. No-op for non-kanban resources and for redirects that don't
        # land on the board (a show page, the table index). Called from
        # ReloadRedirects for all three redirect helpers.
        #
        # Also strips column= so the redirect targets the full board rather than
        # the bare single-column frame endpoint (maybe_render_kanban_column
        # intercepts view=kanban + column=<key>). A card's edit/delete button
        # rendered inside a lazy column frame defaults its return_to to that
        # frame's URL, which carries column=<key>; without this strip the write
        # would redirect onto that fragment instead of the board.
        def kanban_reload_url(url)
          return url unless current_definition.defined_kanban_board
          uri = URI.parse(url.to_s)
          params = Rack::Utils.parse_query(uri.query)
          return url unless params["view"] == "kanban"
          params.delete("column")
          params["kanban_reload"] = "1"
          uri.query = params.to_query
          uri.to_s
        end

        # The user's persisted collapse choice for this column, resolved against
        # the column default. The cookie stores only columns flipped FROM their
        # default (see Kanban::Resource.collapse_cookie_name), so a listed key
        # means "the opposite of the default". Rendering this server-side is what
        # keeps the board in the user's state across morph/stream/reload with no
        # client re-apply — and therefore no flash.
        def kanban_effective_collapsed(column)
          flipped = kanban_collapse_flips.include?(column.key.to_s)
          flipped ? !column.collapsed? : column.collapsed?
        end

        def kanban_collapse_flips
          @kanban_collapse_flips ||= Plutonium::UI::Kanban::Resource.collapse_flips(
            cookies[Plutonium::UI::Kanban::Resource.collapse_cookie_name(resource_class)]
          )
        end

        # Resolves the turbo-frame a card's show link targets, from the board's
        # effective show_in (the board's own value, or the definition's when the
        # board doesn't override it):
        #
        #   :modal → the remote-modal frame, so a card click opens the record in a
        #            centered dialog (the show page is always centered).
        #   :page  → "_top", a full-page navigation to the show route.
        #
        # Either target escapes the column's lazy turbo-frame: "_top" replaces the
        # whole page, and the remote-modal frame lives in the layout (document-wide),
        # so Turbo resolves it outside the column frame.
        def kanban_card_show_frame(board)
          if board.show_in_for(current_definition) == :modal
            Plutonium::REMOTE_MODAL_FRAME
          else
            "_top"
          end
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
          seed.define_singleton_method(:update!) { |attrs = {}|
            assign_attributes(attrs)
            self
          }
          seed.define_singleton_method(:update) { |attrs = {}|
            assign_attributes(attrs)
            true
          }
          seed.define_singleton_method(:save!) { |**| true }
          seed.define_singleton_method(:save) { |**| true }

          if column.on_drop.is_a?(Symbol)
            seed.public_send(column.on_drop)
          else
            kanban_context.instance_exec(seed, &column.on_drop)
          end

          seed.changes.transform_values { |(_, new_val)| new_val }
        end

        # Renders a 422 turbo stream response that re-renders the source column
        # unchanged, allowing the Stimulus drag controller to snap the card back.
        #
        # When a reason is given, a single dismissable toast is appended to the
        # board's #kanban-flash region so the snap-back is explained rather than
        # silent. It renders the shared _toast partial directly (not via flash)
        # so a stale, undisplayed flash from an earlier request can't leak into
        # the turbo_stream response — these move POSTs never render the layout
        # that would otherwise consume the flash.
        def render_kanban_rejection(from_key, reason: nil)
          streams = [
            turbo_stream.update(
              "kanban-col-#{from_key}",
              render_kanban_column_html(from_key.to_s)
            )
          ]

          if reason
            streams << turbo_stream.append(
              "kanban-flash",
              partial: "plutonium/toast",
              locals: {type: :warning, msg: reason}
            )
          end

          render turbo_stream: streams, status: :unprocessable_content
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
