module Plutonium
  module Resource
    class QueryObject
      class << self
      end

      class Query
        include Plutonium::Core::Definers::InputDefiner

        # Applies the query to the given scope using the provided parameters.
        #
        # @param scope [Object] The initial scope to which the query will be applied.
        # @param params [Hash] The parameters for the query.
        # @return [Object] The modified scope.
        def apply(scope, params)
          params = extract_query_params(params)

          if input_definitions.size == params.size
            apply_internal(scope, params)
          else
            scope
          end
        end

        private

        # Abstract method to apply the query logic to the scope.
        # Should be implemented by subclasses.
        #
        # @param scope [Object] The initial scope.
        # @param params [Hash] The parameters for the query.
        # @raise [NotImplementedError] If the method is not implemented.
        def apply_internal(scope, params)
          raise NotImplementedError, "#{self.class}#apply_internal"
        end

        # Extracts query parameters based on the defined inputs.
        #
        # @param params [Hash] The parameters to extract.
        # @return [Hash] The extracted and symbolized parameters.
        def extract_query_params(params)
          input_definitions.collect_all(params).compact.symbolize_keys
        end

        # @return [nil] The resource class (default implementation returns nil).
        def resource_class = nil
      end

      class ScopeQuery < Query
        attr_reader :name

        # Initializes a ScopeQuery with a given name.
        #
        # @param name [Symbol] The name of the scope.
        def initialize(name)
          @name = name
          yield self if block_given?
        end

        private

        # Applies the scope query to the given scope.
        #
        # @param scope [Object] The initial scope.
        # @param params [Hash] The parameters for the query.
        # @return [Object] The modified scope.
        def apply_internal(scope, params)
          scope.send(name, **params)
        end
      end

      class BlockQuery < Query
        attr_reader :body

        # Initializes a BlockQuery with a given block of code.
        #
        # @param body [Proc] The block of code for the query.
        def initialize(body)
          @body = body
          yield self if block_given?
        end

        private

        # Applies the block query to the given scope.
        #
        # @param scope [Object] The initial scope.
        # @param params [Hash] The parameters for the query.
        # @return [Object] The modified scope.
        def apply_internal(scope, params)
          if body.arity == 1
            body.call(scope)
          else
            body.call(scope, **params)
          end
        end
      end

      attr_reader :search_filter, :search_query

      # Initializes a QueryObject with the given context and parameters.
      #
      # @param context [Object] The context in which the query object is used.
      # @param params [Hash] The parameters for initialization.
      def initialize(context, params)
        @context = context

        define_standard_queries
        define_scopes
        define_filters
        define_sorters

        extract_filter_params(params)
        extract_sort_params(params)
      end

      # Builds a URL with the given options for search and sorting.
      #
      # @param options [Hash] The options for building the URL.
      # @return [String] The constructed URL with query parameters.
      def build_url(**options)
        q = {}

        q[:search] = options.key?(:search) ? options[:search].presence : search_query
        q[:scope] = options.key?(:scope) ? options[:scope].presence : selected_scope_filter

        q[:sort_directions] = selected_sort_directions.dup
        q[:sort_fields] = selected_sort_fields.dup
        handle_sort_options!(q, options)

        "?#{{q: q}.to_param}"
      end

      # Applies the defined filters and sorts to the given scope.
      #
      # @param scope [Object] The initial scope to which filters and sorts are applied.
      # @return [Object] The modified scope.
      def apply(scope)
        scope = search_filter.apply(scope, {search: search_query}) if search_filter.present?
        scope = scope_definitions[selected_scope_filter].apply(scope, {}) if selected_scope_filter.present?
        apply_sorts(scope)
      end

      def scope_definitions = @scope_definitions ||= {}.with_indifferent_access

      def filter_definitions = @filter_definitions ||= {}.with_indifferent_access

      def sort_definitions = @sort_definitions ||= {}.with_indifferent_access

      # Provides sorting parameters for the given field name.
      #
      # @param name [Symbol, String] The name of the field to sort.
      # @return [Hash, nil] The sorting parameters including URL and direction.
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

      # Defines standard filters.
      def define_filters
        # Implement filter definitions if needed
      end

      # Defines standard scopes.
      def define_scopes
        # Implement scope definitions if needed
      end

      # Defines standard sorters.
      def define_sorters
        # Implement sorter definitions if needed
      end

      # Defines standard queries for search and scope.
      def define_standard_queries
        define_search(:search) if resource_class.respond_to?(:search)
      end

      # Defines a filter with the given name and body.
      #
      # @param name [Symbol] The name of the filter.
      # @param body [Proc, nil] The body of the filter.
      def define_filter(name, body = nil, &block)
        body ||= name
        filter_definitions[name] = build_query(body, &block)
      end

      # Defines a scope with the given name and body.
      #
      # @param name [Symbol] The name of the scope.
      # @param body [Proc, nil] The body of the scope.
      def define_scope(name, body = nil)
        body ||= name
        scope_definitions[name] = build_query(body)
      end

      # Defines a sort with the given name and body.
      #
      # @param name [Symbol] The name of the sort.
      # @param body [Proc, nil] The body of the sort.
      def define_sorter(name, body = nil)
        if body.nil?
          sort_field = determine_sort_field(name)
          body = ->(scope, direction:) { scope.order(sort_field => direction) }
        end

        sort_definitions[name] = build_query(body) do |query|
          query.define_input :direction
        end
      end

      # Defines a search filter with the given body.
      #
      # @param body [Proc, Symbol] The body of the search filter.
      def define_search(body)
        @search_filter = build_query(body) do |query|
          query.define_input :search
        end
      end

      # Extracts filter parameters from the given params.
      #
      # @param params [Hash] The parameters to extract.
      def extract_filter_params(params)
        @search_query = params[:search]
        @selected_scope_filter = params[:scope]
      end

      # Extracts sort parameters from the given params.
      #
      # @param params [Hash] The parameters to extract.
      def extract_sort_params(params)
        @selected_sort_fields = Array(params[:sort_fields])
        @selected_sort_fields &= sort_definitions.keys

        @selected_sort_directions = extract_sort_directions(params)
      end

      # Builds a query object based on the given body and optional block.
      #
      # @param body [Proc, Symbol] The body of the query.
      # @yieldparam query [Query] The query object.
      # @return [Query] The constructed query object.
      def build_query(body, &block)
        case body
        when Symbol
          raise "Cannot find scope :#{body} on #{resource_class}" unless resource_class.respond_to?(body)

          ScopeQuery.new(body, &block)
        else
          BlockQuery.new(body, &block)
        end
      end

      # Determines the sort field for the given name.
      #
      # @param name [Symbol, String] The name of the field.
      # @return [Symbol] The sort field.
      # @raise [RuntimeError] If unable to determine sort logic.
      def determine_sort_field(name)
        if resource_class.primary_key == name.to_s || resource_class.content_column_field_names.include?(name)
          name
        elsif resource_class.belongs_to_association_field_names.include?(name)
          resource_class.reflect_on_association(name).foreign_key.to_sym
        else
          raise "Unable to determine sort logic for '#{name}'"
        end
      end

      # Extracts sort directions from the given params.
      #
      # @param params [Hash] The parameters to extract.
      # @return [Hash] The extracted sort directions.
      def extract_sort_directions(params)
        params[:sort_directions]&.slice(*sort_definitions.keys) || {}
      end

      # Handles the sort options for building the URL.
      #
      # @param query_params [Hash] The query parameters.
      # @param options [Hash] The options for sorting.
      def handle_sort_options!(query_params, options)
        if (sort = options[:sort])
          handle_sort_reset!(query_params, sort, options[:reset])
        end
      end

      # Handles the reset option for sorting.
      #
      # @param query_params [Hash] The query parameters.
      # @param sort [Symbol, String] The sort field.
      # @param reset [Boolean] Whether to reset the sort.
      def handle_sort_reset!(query_params, sort, reset)
        if reset
          query_params[:sort_fields].delete_if { |e| e == sort.to_s }
          query_params[:sort_directions].delete(sort)
        else
          query_params[:sort_fields] << sort.to_s unless query_params[:sort_fields].include?(sort.to_s)

          sort_direction = selected_sort_directions[sort]
          if sort_direction.nil?
            query_params[:sort_directions][sort] = "ASC"
          elsif sort_direction == "ASC"
            query_params[:sort_directions][sort] = "DESC"
          else
            query_params[:sort_fields].delete_if { |e| e == sort.to_s }
            query_params[:sort_directions].delete(sort)
          end
        end
      end

      # Applies the defined sorters to the given scope.
      #
      # @param scope [Object] The initial scope.
      # @return [Object] The modified scope.
      def apply_sorts(scope)
        selected_sort_fields.each do |name|
          sorter = sort_definitions[name]
          next unless sorter.present?

          params = {direction: selected_sort_directions[name] || "ASC"}
          scope = sorter.apply(scope, params)
        end
        scope
      end

      # @return [Object] The resource class from the context.
      def resource_class = context.resource_class
    end
  end
end
