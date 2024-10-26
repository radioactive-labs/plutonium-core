using Plutonium::Refinements::ParameterRefinements

module Plutonium
  module Resource
    module Controllers
      module Queryable
        extend ActiveSupport::Concern

        included do
          helper_method :raw_resource_query_params, :current_query_object
        end

        def resource_query_object(resource_class, params)
          query_object_class = "#{resource_class}QueryObject".constantize
          query_object_class.new resource_context, params
        end

        def current_query_object
          @current_query_object ||=
            Plutonium::Resource::QueryObject.new(resource_class, raw_resource_query_params) do |query_object|
              if current_definition.search_definition
                query_object.define_search proc { |scope, search:|
                  current_definition.search_definition.call(scope, search)
                }
              end

              current_definition.defined_scopes.each do |key, value|
                query_object.define_scope key, value[:block], **value[:options]
              end

              current_definition.defined_sorts.each do |key, value|
                query_object.define_sorter key, value[:block], **value[:options]
              end

              current_definition.defined_filters.each do |key, value|
                with = value[:options][:with]
                if with.is_a?(Class) && with < Plutonium::Query::Filter
                  options = value[:options].except(:with)
                  options[:key] ||= key
                  with = with.new(**options)
                end
                query_object.define_filter key, with, &value[:block]
              end

              query_object
            end
        end

        def raw_resource_query_params
          params[:q]&.nilify&.to_unsafe_h || {}.with_indifferent_access
        end
      end
    end
  end
end
