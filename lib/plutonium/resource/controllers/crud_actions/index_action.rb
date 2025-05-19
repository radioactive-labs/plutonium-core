module Plutonium
  module Resource
    module Controllers
      module CrudActions
        module IndexAction
          extend ActiveSupport::Concern

          private

          def setup_index_action!
            @pagy, @resource_records = pagy filtered_resource_collection
          end

          def filtered_resource_collection
            query_params = current_definition
              .query_form.new(nil, query_object: current_query_object, page_size: nil)
              .extract_input(params, view_context:)[:q]

            base_query = current_authorized_scope
            current_query_object.apply(base_query, query_params)
          end
        end
      end
    end
  end
end
