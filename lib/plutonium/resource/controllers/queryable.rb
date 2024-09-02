using Plutonium::Refinements::ParameterRefinements

module Plutonium
  module Resource
    module Controllers
      module Queryable
        extend ActiveSupport::Concern

        included do
          helper_method :resource_query_params, :current_query_object
        end

        def resource_query_object(resource_class, params)
          query_object_class = "#{resource_class}QueryObject".constantize
          query_object_class.new resource_context, params
        end

        def current_query_object
          @current_query_object ||= resource_query_object resource_class, resource_query_params
        end

        def resource_query_params
          (params[:q]&.nilify&.to_unsafe_h || {}).with_indifferent_access
        end
      end
    end
  end
end
