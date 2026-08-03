module Plutonium
  module Resource
    module Controllers
      module CrudActions
        module IndexAction
          extend ActiveSupport::Concern

          private

          def setup_index_action!
            # Applied HERE, not inside filtered_resource_collection: what to
            # preload depends on what is about to be RENDERED, and
            # filtered_resource_collection is shared with the CSV export, which
            # renders a different column set (`permitted_attributes_for_export`).
            # Reading the index's fields in there resolved the wrong policy
            # method for that action and raised. Keeping the hook to filtering and
            # eager-loading at the point of use also leaves an app's own
            # `filtered_resource_collection` override unaffected.
            collection = auto_eager_load(filtered_resource_collection, presentable_attributes)
            @pagy, @resource_records = pagy(:offset, collection)
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
