# frozen_string_literal: true

module Plutonium
  module Resource
    module Controllers
      # Drag-reorder endpoint for resources whose definition declares
      # `position_on` — index tables, nested association tables, and grids.
      # (The kanban board has its own richer endpoint: KanbanActions#kanban_move.)
      #
      # ## The request
      #
      #   POST <member>/reposition?<the collection's own query string>
      #   params: prev_id, next_id, to_index
      #
      # prev_id/next_id are the ids of the dropped row's VISIBLE neighbours,
      # either nullable for a drop at an end of the VIEWPORT. A blank id is a
      # claim about the client's page, never about the positioning group: rows
      # hidden by pagination or a filter may still sit beyond it, and Mode A
      # looks the real boundary neighbour up rather than anchoring off nil (see
      # #resolve_position_boundaries — this is what keeps a bottom-of-page drop
      # from writing a duplicate position).
      #
      # The trailing query string is load-bearing, not decoration: it is the
      # index's own query (search / filters / scope / sort / page / view), and it
      # is what lets this action re-render exactly the page the user is looking
      # at — same filters, same page of results — using the ordinary index
      # pipeline rather than a parallel one. Task 7's client must therefore post
      # to the member reposition path with `window.location.search` appended.
      #
      # ## The response
      #
      # The client moves the row optimistically, so a clean drop answers 204 and
      # nothing repaints. The collection is streamed back only when the client's
      # view is or may be stale:
      #
      #   clean Mode A drop, both neighbours resolved  → 204 No Content
      #   reposition! rebalanced the group             → 200 + stream
      #   a neighbour did not resolve (drift)          → 200 + stream
      #   a neighbour belongs to another positioning
      #     group                                      → 200 + stream + toast
      #   Mode B (opaque block write)                  → 200 + stream
      #   denied reposition?                           → 403 + stream + toast
      #   denied index?                                → 403, no body
      #   dropped under a foreign sort                 → 422 + stream + toast
      #   validation failure / record gone             → 422 + stream + toast
      #   no position_on, Mode C, or a kanban view     → 404
      #
      # ## DOM contract (Tasks 7 & 8 depend on these)
      #
      #   #pu-collection-<plural>  the wrapper around the rendered table/grid
      #                            (Plutonium::UI::Page::Index.collection_dom_id)
      #                            — the stream target, and the element the drag
      #                            controller scopes itself to.
      #   #pu-flash                the page's toast region (Plutonium::FLASH_REGION),
      #                            deliberately OUTSIDE the collection wrapper so
      #                            replacing the collection cannot destroy it.
      module PositionActions
        extend ActiveSupport::Concern

        # POST <member>/reposition
        def reposition
          config = current_definition.defined_position_config

          # Not a reorderable surface — a 404, not an authorization failure.
          # Either the resource declares no ordering at all (or Mode C), or the
          # client is on the kanban board, which owns a richer endpoint of its
          # own (kanban_move) and renders no collection wrapper for the
          # reconciliation to target. Checked BEFORE the record is loaded (no
          # point querying for a route that doesn't apply), which means neither
          # verifier has been satisfied by the time we bail — so satisfy both.
          if config.nil? || config.disabled? || position_collection_view == :kanban
            skip_verify_authorize_current!
            skip_verify_current_authorized_scope!
            head :not_found
            return
          end

          # You must be able to SEE a list to reorder it. Without this, a policy
          # with `index? == false, update? == true` would be handed the whole
          # listing by the reconciliation render below. Checked before the
          # record is loaded so the refusal never touches the collection.
          authorize_current! resource_class, to: :index?

          record = current_authorized_scope.find(params[:id])
          authorize_current! record, to: :reposition?

          # Dropping "between the two rows either side of me" only means
          # something when the visual order IS the stored order. Task 7's client
          # doesn't offer the drag under a foreign sort; this is the server-side
          # authority behind that, and it rejects BEFORE any write rather than
          # writing a position derived from neighbours that never implied one.
          if config.delegate? && !current_query_object.sorted_ascending_only_by?(config.attribute)
            return render_position_reconciliation(
              reason: "Reordering is only available while the list is sorted by #{config.attribute.to_s.humanize.downcase}."
            )
          end

          # Resolve neighbours WITHIN the authorized scope. A nil here would mean
          # "drop at the end", so an id that does not resolve must be treated as
          # drift and reconciled — never silently coerced to nil.
          prev_record, prev_ok, prev_drift = resolve_position_neighbour(params[:prev_id], record:, config:)
          next_record, next_ok, next_drift = resolve_position_neighbour(params[:next_id], record:, config:)
          foreign_group = [prev_drift, next_drift].include?(:foreign_group)
          prev_record, next_record = resolve_position_boundaries(record, config, prev_record, next_record)

          # Nothing left to anchor to. In Mode A that is never a real drag — a
          # list you can drag in has a row on one side of the drop, and the
          # boundary lookup above supplies the other. It means the client's view
          # is stale (both neighbours drifted), and writing anyway would send the
          # record to position 0.0 at the head of its group on the strength of a
          # request we've just decided not to trust. Reconcile instead: the row
          # snaps back to where it actually is.
          if config.delegate? && prev_record.nil? && next_record.nil?
            # A cross-group drop lands here with BOTH neighbours rejected, and is
            # the one kind of drift worth explaining: it is a standing property
            # of a list that spans groups, not transient staleness. Status stays
            # :ok — the reconciliation is unchanged, this only adds the toast.
            return render_position_reconciliation(
              reason: foreign_group ? position_foreign_group_reason(record) : nil,
              status: :ok
            )
          end

          # Bind the return rather than branching on the call directly:
          # `if config.reposition!(...)` reads as a success check, which this is
          # NOT — failure raises. The boolean means "positions other than this
          # record's may have changed, so the client's optimistic view is stale".
          must_reconcile = config.reposition!(
            record:,
            prev_record:,
            next_record:,
            # Floor-clamped, mirroring the kanban drop (KanbanActions#kanban_move
            # clamps to [0, size]): a negative index reaching a Mode B block
            # would index its array from the END, silently anchoring the drop to
            # the wrong row. There is no card list here to give it a ceiling, so
            # the contract Move#index carries is "0 or greater".
            index: [params[:to_index].to_i, 0].max
          )

          # No reason here, even when a neighbour was out of group: reposition!
          # has already run, so the record DID move — the surviving anchor
          # carried the drop and resolve_position_boundaries supplied the other.
          # Telling the user reordering "only works within the same group" on a
          # move that just worked contradicts what they can see. The refusal
          # above is the only place that claim is true.
          if must_reconcile || !prev_ok || !next_ok
            render_position_reconciliation
          else
            head :no_content
          end
        rescue ::ActionPolicy::Unauthorized => e
          # NOTE: the leading :: is REQUIRED — Plutonium::ActionPolicy exists, so
          # a bare ActionPolicy resolves to that namespace and never matches,
          # letting the exception reach the global rescue_from, which re-raises
          # for turbo_stream requests → an HTML error page morphed into the table.
          #
          # authorize_count only bumps after a SUCCESSFUL authorize, so a denial
          # leaves the verifier unsatisfied; we handled authorization by rejecting.
          skip_verify_authorize_current!

          # A denied index? is not a snap-back: the user may not see this listing
          # at all, so the refusal must not carry it back to them. Only a denied
          # reposition? gets the collection (the row has to return somewhere).
          if e.rule.to_sym == :index?
            skip_verify_current_authorized_scope!
            head :forbidden
            return
          end

          render_position_reconciliation(
            reason: "You are not authorized to reorder this.",
            status: :forbidden
          )
        rescue ActiveRecord::RecordNotFound
          # The row was destroyed between render and drop. `find` raised before
          # authorize_current!, so satisfy that verifier explicitly.
          skip_verify_authorize_current!
          render_position_reconciliation(reason: "This record no longer exists.")
        rescue ActiveRecord::RecordInvalid => e
          reason = e.record.errors.full_messages.to_sentence.presence ||
            "This record could not be moved."
          render_position_reconciliation(reason:)
        end

        private

        # Returns [neighbour, resolved?]. A blank id is a legitimate end-of-page
        # drop → [nil, true]. Anything the client named that we cannot honour is
        # drift → [nil, false], which forces reconciliation.
        #
        # Two ways to fail. The id may not resolve in the authorized scope at
        # all; or it may resolve to a row in a DIFFERENT positioning group. The
        # second is not exotic — a status-scoped resource lists several groups
        # in one table, with independent and freely interleaved numberings, so
        # anchoring off a neighbour from another group flings the record to an
        # arbitrary point in its own. Group membership is part of "can this
        # neighbour anchor this drop", so it belongs here rather than in a
        # separate check the caller could forget.
        # Returns [neighbour, ok, drift]. `drift` names WHY a neighbour was
        # rejected — :missing (gone, or outside this viewer's scope) versus
        # :foreign_group (real, but in another positioning group). Both reconcile
        # identically, but only the second has something worth telling the user:
        # it is a standing property of the list they are looking at, not a
        # transient staleness that a reload fixes.
        def resolve_position_neighbour(id, record:, config:)
          return [nil, true, nil] if id.blank?

          neighbour = current_authorized_scope.find_by(id: id)
          return [nil, false, :missing] if neighbour.nil?

          # Mode B owns its own storage AND its own notion of a group; only the
          # framework's own scope attribute is ours to police.
          group_attr = config.delegate? ? record.class.positioning_scope_attr : nil
          return [nil, false, :foreign_group] if group_attr && neighbour[group_attr] != record[group_attr]

          [neighbour, true, nil]
        end

        # What to tell the user when a drop was refused because its neighbours
        # belong to another positioning group — the case a collection spanning
        # groups (a top-level index of a resource scoped to its parent) invites
        # on nearly every row. Named after the scope attribute so the message
        # says "the same product" rather than restating the column.
        def position_foreign_group_reason(record)
          scope = record.class.positioning_scope_attr.to_s.delete_suffix("_id").humanize.downcase
          "Reordering only works within the same #{scope}."
        end

        # Fills in a neighbour the CLIENT could not see.
        #
        # A blank neighbour id means "nothing on that side of my viewport" — it
        # does NOT mean "nothing on that side of the group". Pagination and
        # filters both hide rows, so the last visible row is routinely not the
        # last row. Taken literally, position_between would compute prev + 1 (or
        # next - 1), which on a default-spaced list is EXACTLY the position of
        # the row the client couldn't see: a silent duplicate, reported as a
        # clean drop, that only heals if someone later drags between the tied
        # pair. So we look the real boundary neighbour up instead.
        #
        # The lookup deliberately runs against the model's own group, NOT the
        # authorized scope: a position is a property of the group, and ignoring
        # rows the viewer can't see is the very bug being fixed. Nothing about
        # the hidden row reaches the client — only the dropped record's own
        # resulting position, which had to interleave with it either way.
        #
        # Mode A only: a Mode B block owns its neighbour semantics, and receives
        # the drop exactly as the client described it.
        def resolve_position_boundaries(record, config, prev_record, next_record)
          return [prev_record, next_record] unless config.delegate?
          return [prev_record, next_record] if prev_record && next_record

          attr = config.attribute
          group = positioning_group_for(record)

          if next_record.nil? && prev_record
            next_record = group.where(group.table[attr].gt(prev_record[attr])).order(attr => :asc).first
          elsif prev_record.nil? && next_record
            prev_record = group.where(group.table[attr].lt(next_record[attr])).order(attr => :desc).first
          end

          [prev_record, next_record]
        end

        # The record's positioning group, minus the record itself (it is being
        # moved, so its current slot must not anchor its new one). Mirrors
        # Positioning::Model#positioning_group_relation, which is private to the
        # model instance.
        def positioning_group_for(record)
          klass = record.class
          relation = klass.all
          group_attr = klass.positioning_scope_attr
          relation = relation.where(group_attr => record[group_attr]) if group_attr
          relation.where.not(klass.primary_key => record.id)
        end

        # Streams the collection back so the client's optimistic DOM is replaced
        # by the server's truth — the row snaps back on rejection, or settles
        # into its rebalanced order.
        #
        # The status defaults off `reason`: a reconciliation that has something
        # to say is a REJECTION (422 unless the caller is more specific), while a
        # silent one is a successful drop whose result simply differs from what
        # the client drew (a rebalance, drift, a Mode B write).
        #
        # The toast renders the shared _toast partial directly rather than going
        # through `flash`, exactly as the kanban rejection does: this action never
        # renders the layout that would consume a flash, so a stale entry from an
        # earlier request would otherwise leak into the stream.
        def render_position_reconciliation(reason: nil, status: reason ? :unprocessable_content : :ok)
          streams = [
            turbo_stream.update(
              Plutonium::UI::Page::Index.collection_dom_id(resource_class),
              render_position_collection_html
            )
          ]

          if reason
            streams << turbo_stream.append(
              Plutonium::FLASH_REGION,
              partial: "plutonium/toast",
              locals: {type: :warning, msg: reason}
            )
          end

          render turbo_stream: streams, status:
        end

        # Renders the collection component to an HTML-safe string.
        #
        # This is the INDEX's own pipeline, not a copy of it: setup_index_action!
        # applies search / filters / scopes / tenant scoping AND the same
        # pagination, driven by the index query string the client posted with. So
        # the rows streamed back are precisely the rows the user is looking at —
        # page 3 of a filtered list comes back as page 3 of that filtered list.
        #
        # (Kanban's equivalent, kanban_base_relation, deliberately drops
        # pagination because a board pages per column instead. A table has one
        # pager for the whole collection, so reusing setup_index_action! whole is
        # both simpler and more correct here.)
        #
        # The action is passed explicitly as "index": this request's action_name
        # is "reposition", and a resource must not have to define
        # permitted_attributes_for_reposition to be draggable.
        def render_position_collection_html
          setup_index_action!(action: "index")

          component = (position_collection_view == :grid) ?
            build_grid_collection(action: "index") :
            build_collection(action: "index")

          view_context.render(component).html_safe
        end

        # Which of the resource's index views the client is looking at, resolved
        # exactly as the index page resolves it (?view= → cookie → default).
        def position_collection_view
          @position_collection_view ||= Plutonium::UI::Page::Index.resolve_view(
            current_definition, resource_class, params[:view], cookies
          )
        end

        # The collection path this drop belongs to — the index (or nested
        # association) URL the client is displaying, NOT this POST-only member
        # path. Overriding the two Core::Controller seams re-points every URL the
        # re-rendered collection builds — sort headers, the search form, filter
        # pills, pagination, each row action's return_to — at that page. Without
        # it a rebalanced table would come back wired to /tasks/5/reposition,
        # where every one of those links is a 404 waiting to happen.
        #
        # Guarded on the action: every OTHER action on this controller genuinely
        # is the page it renders, and must keep the request-derived defaults.
        def current_page_path
          return super unless action_name == "reposition"
          position_collection_path
        end

        # Absolute, like the request.original_url it stands in for — a consumer
        # that got a path here where every other action hands it a full URL
        # would be a trap. request.base_url is this request's own origin, which
        # is the page's origin too: the drop was posted from it.
        def current_page_url
          return super unless action_name == "reposition"
          @position_page_url ||= begin
            query = request.query_string
            "#{request.base_url}#{position_collection_path}#{"?#{query}" if query.present?}"
          end
        end

        # Pagy carries the request params into every page link. Under this POST
        # that would smuggle prev_id/next_id/to_index into them, so hand Pagy the
        # query string alone — which is the index's own params.
        def pagy_request_context
          return super unless action_name == "reposition"
          super.merge(params: request.GET.to_h)
        end

        # The collection path this drop belongs to. `parent:` is what makes a
        # nested association table work: resource_url_for ignores current_parent
        # unless it is passed one, so without it a drop inside
        # /posts/1/nested_comments would resolve to the TOP-LEVEL /comments and
        # send every link in the streamed collection out of the frame, at the
        # wrong collection. current_parent is nil off a nested route, where
        # `parent: nil` is exactly the top-level lookup we want.
        def position_collection_path
          @position_collection_path ||= resource_url_for(resource_class, parent: current_parent)
        end
      end
    end
  end
end
