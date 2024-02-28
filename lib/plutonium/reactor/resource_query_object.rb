# TODO: refactor
module Plutonium
  # TODO: make standard query type names e.g. search and scope configurable
  module Reactor
    class ResourceQueryObject
      class << self
      end

      class Query
        include Plutonium::Core::Definers::InputDefiner

        def apply(scope, params)
          params = extract_query_params params

          if input_definitions.size == params.size
            apply_internal scope, params
          else
            scope
          end
        end

        private

        def apply_internal(scope, params)
          raise NotImplementedError, "#{self.class}#apply_internal"
        end

        def extract_query_params(params)
          input_definitions.collect_all(params).symbolize_keys
        end

        def resource_class = nil
      end

      class ScopeQuery < Query
        attr_reader :name

        def initialize(name)
          @name = name
          yield self if block_given?
        end

        private

        def apply_internal(scope, params)
          scope.send name, **params
        end
      end

      class BlockQuery < Query
        attr_reader :body

        def initialize(body)
          @body = body
          yield self if block_given?
        end

        def apply_internal(scope, params)
          if body.arity == 1
            body.call scope
          else
            body.call scope, **params
          end
        end
      end

      attr_reader :search_filter, :search_query

      def initialize(context, params)
        @context = context

        define_standard_queries
        define_scopes
        define_filters
        define_sorters

        params = params&.dup
        extract_filter_params(params)
        extract_sort_params(params)
        @params = (params&.except(:scope, :search, :sort_fields, :sort_directions)&.permit!.to_h || {}).with_indifferent_access
      end

      def build_url(**options)
        q = {}

        q[:search] = options.key?(:search) ? options[:search].presence : search_query
        q[:scope] = options.key?(:scope) ? options[:scope].presence : selected_scope_filter

        q[:sort_directions] = selected_sort_directions.dup
        q[:sort_fields] = selected_sort_fields.dup
        if (sort = options[:sort])
          if options[:reset]
            q[:sort_fields].delete_if { |e| e == sort.to_s }
            q[:sort_directions].delete sort
          else
            q[:sort_fields] << sort.to_s unless q[:sort_fields].include?(sort.to_s)

            sort_direction = selected_sort_directions[sort]
            if sort_direction.nil?
              q[:sort_directions][sort] = "ASC"
            elsif sort_direction == "ASC"
              q[:sort_directions][sort] = "DESC"
            else
              q[:sort_fields].delete_if { |e| e == sort.to_s }
              q[:sort_directions].delete sort
            end
          end
        end

        "?#{{q: q}.to_param}"
      end

      def apply(scope)
        scope = search_filter.apply(scope, {search: search_query}) if search_filter.present?
        scope = scope_definitions[selected_scope_filter].apply(scope, {}) if selected_scope_filter.present?
        selected_sort_fields.each do |name|
          sorter = sort_definitions[name]
          next unless sorter.present?

          params = {direction: selected_sort_directions[name] || "ASC"}
          scope = sorter.apply(scope, params)
        end
        scope
      end

      def scope_definitions = @scope_definitions ||= {}.with_indifferent_access

      def filter_definitions = @filter_definitions ||= {}.with_indifferent_access

      def sort_definitions = @sort_definitions ||= {}.with_indifferent_access

      def sort_params_for(name)
        return unless sort_definitions[name]

        {
          url: build_url(sort: name),
          reset_url: build_url(sort: name, reset: true),
          position: selected_sort_fields.index(name.to_s),
          direction: selected_sort_directions[name]
        }
      end

      private

      attr_reader :context, :selected_sort_fields, :selected_sort_directions, :selected_scope_filter

      def define_filters
      end

      def define_scopes
      end

      def define_sorters
      end

      def define_standard_queries
        define_search(:search) if resource_class.respond_to?(:search)
      end

      def define_filter(name, body = nil, &block)
        body ||= name
        filter_definitions[name] = build_query(body, &block)
      end

      def define_scope(name, body = nil)
        body ||= name
        scope_definitions[name] = build_query(body)
      end

      def define_sort(name, body = nil)
        if body.nil?
          sort_field = if resource_class.primary_key == name.to_s || resource_class.content_column_field_names.include?(name)
            name
          elsif resource_class.belongs_to_association_field_names.include? name
            Comment.reflect_on_association(name).foreign_key.to_sym
          else
            raise "Unable to determine sort logic for '#{body}'"
          end
          body = lambda { |scope, direction:| scope.order(sort_field => direction) }
        end

        sort_definitions[name] = build_query(body) do |query|
          query.define_input :direction
        end
      end

      def define_search(body)
        @search_filter = build_query(body) do |query|
          query.define_input :search
        end
      end

      def extract_filter_params(params)
        @search_query = params&.permit(:search)&.[](:search)
        @selected_scope_filter = params&.permit(:scope)&.[](:scope)
      end

      def extract_sort_params(params)
        @selected_sort_fields = params&.permit(sort_fields: [])&.[](:sort_fields) || []
        @selected_sort_fields &= sort_definitions.keys

        @selected_sort_directions = (params&.permit(sort_directions: sort_definitions.keys)&.[](:sort_directions) || {}).to_h.with_indifferent_access
        @selected_sort_directions = @selected_sort_directions.map { |key, value| [key, {"DESC" => "DESC"}[value.upcase] || "ASC"] }.to_h.with_indifferent_access
      end

      def build_query(body, &block)
        case body
        when Symbol
          ScopeQuery.new(body, &block)
        else
          BlockQuery.new(body, &block)
        end
      end

      def resource_class = context.resource_class
    end
  end
end
