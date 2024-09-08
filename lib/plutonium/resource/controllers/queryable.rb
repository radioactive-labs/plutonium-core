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
          @current_query_object ||= Plutonium::Resource::QueryObject.new(resource_context, resource_query_params) do |query_object|
            if current_definition.search_definition
              query_object.define_search proc { |scope, search:|
                current_definition.search_definition.call(scope, search)
              }
            end

            current_definition.defined_scopes.each do |key, value|
              query_object.define_scope key, value[:block]
            end

            current_definition.defined_sorts.each do |key, value|
              query_object.define_sorter key, value[:block]
            end

            query_object
          end
        end

        def resource_query_params
          (params[:q]&.nilify&.to_unsafe_h || {}).with_indifferent_access
        end
      end
    end
  end
end
