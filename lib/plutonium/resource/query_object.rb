# TODO: make standard query type names e.g. search and scope configurable

module Plutonium
  module Resource
    # The QueryObject class is responsible for handling various query types and applying them to the given scope.
    class QueryObject
      class << self
      end

      # The Query class serves as a base for different types of queries.
      class Query
        include Plutonium::Core::Definers::InputDefiner

        # Applies the query to the given scope with the provided parameters.
        #
        # @param scope [Object] the scope to apply the query on
        # @param params [Hash] the parameters for the query
        # @return [Object] the modified scope
        def apply(scope, params)
          params = extract_query_params(params)
          (input_definitions.size == params.size) ? apply_internal(scope, params) : scope
        end

        private

        # Raises an error, should be implemented by subclasses.
        #
        # @param scope [Object] the scope to apply the query on
        # @param params [Hash] the parameters for the query
        # @raise [NotImplementedError] if not implemented by subclass
        def apply_internal(scope, params)
          raise NotImplementedError, "#{self.class}#apply_internal"
        end

        # Extracts and processes query parameters.
        #
        # @param params [Hash] the parameters to process
        # @return [Hash] the processed parameters
        def extract_query_params(params)
          input_definitions.collect_all(params).compact.symbolize_keys
        end

        # Returns the resource class, to be implemented by subclasses.
        #
        # @return [Class, nil] the resource class
        def resource_class
          nil
        end
      end

      # The ScopeQuery class represents a query based on a scope.
      class ScopeQuery < Query
        attr_reader :name

        # Initializes a ScopeQuery.
        #
        # @param name [Symbol] the name of the scope
        # @yield [self] optional block to configure the query
        def initialize(name)
          @name = name
          yield self if block_given?
        end

        private

        # Applies the scope query to the given scope with the provided parameters.
        #
        # @param scope [Object] the scope to apply the query on
        # @param params [Hash] the parameters for the query
        # @return [Object] the modified scope
        def apply_internal(scope, params)
          scope.send(name, **params)
        end
      end

      # The BlockQuery class represents a query based on a block.
      class BlockQuery < Query
        attr_reader :body

        # Initializes a BlockQuery.
        #
        # @param body [Proc] the block to apply
        # @yield [self] optional block to configure the query
        def initialize(body)
          @body = body
          yield self if block_given?
        end

        private

        # Applies the block query to the given scope with the provided parameters.
        #
        # @param scope [Object] the scope to apply the query on
        # @param params [Hash] the parameters for the query
        # @return [Object] the modified scope
        def apply_internal(scope, params)
          (body.arity == 1) ? body.call(scope) : body.call(scope, **params)
        end
      end

      attr_reader :search_filter, :search_query, :context, :selected_sort_fields, :selected_sort_directions, :selected_scope_filter

      # Initializes a QueryObject.
      #
      # @param context [Object] the context in which the queries are defined
      # @param params [Hash] the initial parameters for the query object
      def initialize(context, params)
        @context = context

        define_standard_queries
        define_scopes
        define_filters
        define_sorters

        extract_filter_params(params)
        extract_sort_params(params)
      end

      # Builds a URL with the current query parameters.
      #
      # @param options [Hash] additional options for building the URL
      # @return [String] the built URL
      def build_url(**options)
        q = {}
        q[:search] = options.fetch(:search, search_query).presence
        q[:scope] = options.fetch(:scope, selected_scope_filter).presence
        q[:sort_directions] = selected_sort_directions.dup
        q[:sort_fields] = selected_sort_fields.dup

        if (sort = options[:sort])
          handle_sort_options(q, sort, options[:reset])
        end

        "?#{{q: q}.to_param}"
      end

      # Applies the queries to the given scope.
      #
      # @param scope [Object] the scope to apply the queries on
      # @return [Object] the modified scope
      def apply(scope)
        scope = search_filter.apply(scope, {search: search_query}) if search_filter.present?
        scope = scope_definitions[selected_scope_filter].apply(scope, {}) if selected_scope_filter.present?
        apply_sorters(scope)
      end

      # Retrieves the scope definitions.
      #
      # @return [HashWithIndifferentAccess] the scope definitions
      def scope_definitions
        @scope_definitions ||= {}.with_indifferent_access
      end

      # Retrieves the filter definitions.
      #
      # @return [HashWithIndifferentAccess] the filter definitions
      def filter_definitions
        @filter_definitions ||= {}.with_indifferent_access
      end

      # Retrieves the sort definitions.
      #
      # @return [HashWithIndifferentAccess] the sort definitions
      def sort_definitions
        @sort_definitions ||= {}.with_indifferent_access
      end

      # Retrieves the sort parameters for a given name.
      #
      # @param name [Symbol] the name of the sort field
      # @return [Hash, nil] the sort parameters or nil if not defined
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

      # Placeholder method for defining filters.
      def define_filters
      end

      # Placeholder method for defining scopes.
      def define_scopes
      end

      # Placeholder method for defining sorters.
      def define_sorters
      end

      # Defines standard queries.
      def define_standard_queries
        define_search(:search) if resource_class.respond_to?(:search)
      end

      # Defines a filter.
      #
      # @param name [Symbol] the name of the filter
      # @param body [Proc, nil] the body of the filter
      # @yield [Query] optional block to configure the query
      def define_filter(name, body = nil, &block)
        body ||= name
        filter_definitions[name] = build_query(body, &block)
      end

      # Defines a scope.
      #
      # @param name [Symbol] the name of the scope
      # @param body [Proc, nil] the body of the scope
      def define_scope(name, body = nil)
        body ||= name
        scope_definitions[name] = build_query(body)
      end

      # Defines a sort.
      #
      # @param name [Symbol] the name of the sort field
      # @param body [Proc, nil] the body of the sort
      def define_sort(name, body = nil)
        if body.nil?
          sort_field = determine_sort_field(name)
          body = ->(scope, direction:) { scope.order(sort_field => direction) }
        end
        sort_definitions[name] = build_query(body) do |query|
          query.define_input :direction
        end
      end

      # Defines a search filter.
      #
      # @param body [Proc] the body of the search filter
      def define_search(body)
        @search_filter = build_query(body) do |query|
          query.define_input :search
        end
      end

      # Extracts filter parameters from the given params.
      #
      # @param params [Hash] the parameters to extract from
      def extract_filter_params(params)
        @search_query = params[:search]
        @selected_scope_filter = params[:scope]
      end

      # Extracts sort parameters from the given params.
      #
      # @param params [Hash] the parameters to extract from
      def extract_sort_params(params)
        @selected_sort_fields = Array(params[:sort_fields]) & sort_definitions.keys
        @selected_sort_directions = (params[:sort_directions]&.slice(*sort_definitions.keys) || {}).transform_values { |v| (v.upcase == "DESC") ? "DESC" : "ASC" }.with_indifferent_access
      end

      # Builds a query object.
      #
      # @param body [Symbol, Proc] the body of the query
      # @yield [Query] optional block to configure the query
      # @return [Query] the built query object
      def build_query(body, &block)
        case body
        when Symbol
          raise "Cannot find scope :#{body} on #{resource_class}" unless resource_class.respond_to?(body)
          ScopeQuery.new(body, &block)
        else
          BlockQuery.new(body, &block)
        end
      end

      # Retrieves the resource class.
      #
      # @return [Class] the resource class
      def resource_class
        context.resource_class
      end

      # Determines the sort field for a given name.
      #
      # @param name [Symbol] the name of the sort field
      # @return [Symbol] the determined sort field
      # @raise [RuntimeError] if unable to determine sort logic for the field
      def determine_sort_field(name)
        if resource_class.primary_key == name.to_s || resource_class.content_column_field_names.include?(name)
          name
        elsif resource_class.belongs_to_association_field_names.include?(name)
          resource_class.reflect_on_association(name).foreign_key.to_sym
        else
          raise "Unable to determine sort logic for '#{name}'"
        end
      end

      # Handles sorting options.
      #
      # @param query [Hash] the query parameters
      # @param sort [Symbol] the sort field
      # @param reset [Boolean] whether to reset the sorting
      def handle_sort_options(query, sort, reset)
        if reset
          query[:sort_fields].delete_if { |e| e == sort.to_s }
          query[:sort_directions].delete(sort)
        else
          query[:sort_fields] << sort.to_s unless query[:sort_fields].include?(sort.to_s)
          sort_direction = selected_sort_directions[sort]
          query[:sort_directions][sort] = if sort_direction.nil?
            "ASC"
          else
            ((sort_direction == "ASC") ? "DESC" : "ASC")
          end
          query[:sort_fields].delete_if { |e| e == sort.to_s } if query[:sort_directions][sort] == "ASC"
        end
      end

      # Applies sorters to the scope.
      #
      # @param scope [Object] the scope to apply sorters on
      # @return [Object] the modified scope
      def apply_sorters(scope)
        selected_sort_fields.each do |name|
          sorter = sort_definitions[name]
          next unless sorter.present?
          scope = sorter.apply(scope, {direction: selected_sort_directions[name] || "ASC"})
        end
        scope
      end
    end
  end
end
