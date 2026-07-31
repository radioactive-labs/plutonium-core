module Plutonium
  module Resource
    module Controllers
      module CrudActions
        module IndexAction
          extend ActiveSupport::Concern

          private

          def setup_index_action!
            @pagy, @resource_records = pagy(:offset, filtered_resource_collection, request: pagy_request_context)
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
