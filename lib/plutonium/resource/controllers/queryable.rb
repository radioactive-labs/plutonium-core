module Plutonium
  module Resource
    module Controllers
      module Queryable
        extend ActiveSupport::Concern

        included do
          helper_method :raw_resource_query_params, :current_query_object
        end

        def current_query_object
          @current_query_object ||=
            Plutonium::Resource::QueryObject.new(resource_class, raw_resource_query_params, request.path) do |query_object|
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

              if current_definition.respond_to?(:default_sort) && current_definition.default_sort
                query_object.default_sort_config = current_definition.default_sort
              end

              if current_definition.respond_to?(:default_scope) && current_definition.default_scope
                query_object.default_scope_name = current_definition.default_scope
              end

              current_definition.defined_filters.each do |key, value|
                with = value[:options][:with]
                if with
                  # Resolve symbol types (e.g., :text, :select) to filter classes
                  filter_class = Plutonium::Query::Filter.lookup(with)
                  options = value[:options].except(:with)
                  options[:key] ||= key
                  with = filter_class.new(**options)
                end
                query_object.define_filter key, with, &value[:block]
              end

              query_object
            end
        end

        def raw_resource_query_params
          @raw_resource_query_params ||= begin
            query_params = params[:q]
            if query_params.is_a?(ActionController::Parameters)
              query_params.to_unsafe_h
            else
              {}.with_indifferent_access
            end
          end
        end
      end
    end
  end
end
