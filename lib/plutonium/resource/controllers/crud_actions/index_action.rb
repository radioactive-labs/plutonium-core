module Plutonium
  module Resource
    module Controllers
      module CrudActions
        module IndexAction
          extend ActiveSupport::Concern

          private

          # `action` names the action whose field set is about to be rendered.
          # It defaults to the current one, and the reposition drop POST passes
          # "index" for the same reason it does when building the collection: it
          # re-renders the index on the index's behalf, and a resource must not
          # have to define permitted_attributes_for_reposition to be draggable.
          def setup_index_action!(action: action_name)
            # Applied HERE, not inside filtered_resource_collection: what to
            # preload depends on what is about to be RENDERED, and
            # filtered_resource_collection is shared with the CSV export, which
            # renders a different column set (`permitted_attributes_for_export`).
            # Reading the index's fields in there resolved the wrong policy
            # method for that action and raised. Keeping the hook to filtering and
            # eager-loading at the point of use also leaves an app's own
            # `filtered_resource_collection` override unaffected.
            collection = auto_eager_load(filtered_resource_collection, presentable_attributes_for(action))
            @pagy, @resource_records = pagy(:offset, collection, request: pagy_request_context)
          end

          # What Pagy builds its page URLs from. Pagy accepts either the real
          # request object or a plain hash (Pagy::Request), which is the seam we
          # need: an action that re-renders the collection on the index's behalf
          # (the reposition drop POST) must emit page links pointing at the index
          # page, not at its own POST-only path. current_page_path is that page —
          # it equals request.path for a genuine index request, so the default is
          # exactly today's behaviour.
          def pagy_request_context
            {
              base_url: request.base_url,
              path: current_page_path,
              params: request.GET.merge(request.POST).to_h,
              cookie: request.cookies["pagy"]
            }
          end

          def filtered_resource_collection
            query_params = current_definition
              .query_form.new(nil, query_object: current_query_object, page_size: nil)
              .extract_input(params, view_context:)[:q]

            base_query = current_authorized_scope
            current_query_object.apply(base_query, query_params, context: self)
          end
        end
      end
    end
  end
end
