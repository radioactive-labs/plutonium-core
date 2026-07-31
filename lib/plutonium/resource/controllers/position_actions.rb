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
      # either nullable for a drop at an end of the list.
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
      #   a neighbour id did not resolve (drift)       → 200 + stream
      #   Mode B (opaque block write)                  → 200 + stream
      #   policy denial                                → 403 + stream + toast
      #   validation failure / record gone             → 422 + stream + toast
      #   no position_on, or Mode C                    → 404
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

          if config.nil? || config.disabled?
            # Not a reorderable resource — a 404, not an authorization failure.
            # Checked BEFORE the record is loaded (no point querying for a route
            # that doesn't apply), which means neither verifier has been
            # satisfied by the time we bail — so satisfy both explicitly.
            skip_verify_authorize_current!
            skip_verify_current_authorized_scope!
            head :not_found
            return
          end

          record = current_authorized_scope.find(params[:id])
          authorize_current! record, to: :reposition?

          # Resolve neighbours WITHIN the authorized scope. A nil here would mean
          # "drop at the end", so an id that does not resolve must be treated as
          # drift and reconciled — never silently coerced to nil.
          prev_record, prev_ok = resolve_position_neighbour(params[:prev_id])
          next_record, next_ok = resolve_position_neighbour(params[:next_id])

          # Bind the return rather than branching on the call directly:
          # `if config.reposition!(...)` reads as a success check, which this is
          # NOT — failure raises. The boolean means "positions other than this
          # record's may have changed, so the client's optimistic view is stale".
          must_reconcile = config.reposition!(
            record:,
            prev_record:,
            next_record:,
            index: params[:to_index].to_i
          )

          if must_reconcile || !prev_ok || !next_ok
            render_position_reconciliation
          else
            head :no_content
          end
        rescue ::ActionPolicy::Unauthorized
          # NOTE: the leading :: is REQUIRED — Plutonium::ActionPolicy exists, so
          # a bare ActionPolicy resolves to that namespace and never matches,
          # letting the exception reach the global rescue_from, which re-raises
          # for turbo_stream requests → an HTML error page morphed into the table.
          #
          # authorize_count only bumps after a SUCCESSFUL authorize, so a denial
          # leaves the verifier unsatisfied; we handled authorization by rejecting.
          skip_verify_authorize_current!
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

        # Returns [record, resolved?]. A blank id is a legitimate end-of-list
        # drop → [nil, true]. An id that does not resolve in the authorized scope
        # is drift → [nil, false], which forces reconciliation.
        def resolve_position_neighbour(id)
          return [nil, true] if id.blank?
          record = current_authorized_scope.find_by(id: id)
          [record, !record.nil?]
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
          setup_index_action!

          view = Plutonium::UI::Page::Index.resolve_view(
            current_definition, resource_class, params[:view], cookies
          )
          component = (view == :grid) ? build_grid_collection(action: "index") : build_collection(action: "index")

          view_context.render(component).html_safe
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
          @position_page_path ||= URI.parse(position_collection_url).path
        end

        def current_page_url
          return super unless action_name == "reposition"
          @position_page_url ||= begin
            query = request.query_string
            query.present? ? "#{position_collection_url}?#{query}" : position_collection_url
          end
        end

        # Pagy carries the request params into every page link. Under this POST
        # that would smuggle prev_id/next_id/to_index into them, so hand Pagy the
        # query string alone — which is the index's own params.
        def pagy_request_context
          return super unless action_name == "reposition"
          super.merge(params: request.GET.to_h)
        end

        def position_collection_url
          @position_collection_url ||= resource_url_for(resource_class)
        end
      end
    end
  end
end
