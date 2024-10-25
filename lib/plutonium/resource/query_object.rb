module Plutonium
  module Resource
    class QueryObject
      class Form < Plutonium::UI::Form::Query; end

      attr_reader :search_filter, :search_query

      # Initializes a QueryObject with the given resource_class and parameters.
      #
      # @param resource_class [Object] The resource class.
      # @param params [Hash] The parameters for initialization.
      def initialize(resource_class, params, &)
        @resource_class = resource_class
        @params = params

        define_standard_queries
        yield self if block_given?
        extract_filter_params
        extract_sort_params
      end

      # Defines a filter with the given name and body.
      #
      # @param name [Symbol] The name of the filter.
      # @param body [Proc, nil] The body of the filter.
      def define_filter(name, body, &)
        filter_definitions[name] = build_query(body, &)
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
      def define_sorter(name, body = nil, using: nil)
        if body.nil?
          sort_field = using || determine_sort_field(name)
          body = ->(scope, direction:) { scope.order(sort_field => direction) }
        end

        sort_definitions[name] = build_query(body) do |query|
          query.input :direction
        end
      end

      # Defines a search filter with the given body.
      #
      # @param body [Proc, Symbol] The body of the search filter.
      def define_search(body)
        @search_filter = build_query(body) do |query|
          query.input :search
        end
      end

      def build_form(params = nil, page_size: nil)
        self.class::Form.new(params, as: :q, query_object: self, page_size:, attributes: {id: SecureRandom.hex})
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
        scope = search_filter.apply(scope, {search: search_query}) if search_filter
        scope = scope_definitions[selected_scope_filter].apply(scope, {}) if selected_scope_filter
        scope = apply_sorts(scope)
        apply_filters(scope)
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

      attr_reader :resource_class, :params, :selected_sort_fields, :selected_sort_directions, :selected_scope_filter

      # Defines standard queries for search and scope.
      def define_standard_queries
        define_search(:search) if resource_class.respond_to?(:search)
      end

      # Extracts filter parameters from the given params.
      #
      # @param params [Hash] The parameters to extract.
      def extract_filter_params
        @search_query = params[:search]
        @selected_scope_filter = params[:scope]
      end

      # Extracts sort parameters from the given params.
      #
      # @param params [Hash] The parameters to extract.
      def extract_sort_params
        @selected_sort_fields = Array(params[:sort_fields])
        @selected_sort_fields &= sort_definitions.keys

        @selected_sort_directions = extract_sort_directions(params)
      end

      # Builds a query object based on the given body and optional block.
      #
      # @param body [Proc, Symbol] The body of the query.
      # @yieldparam query [Plutonium::Query::Base] The query object.
      # @return [Plutonium::Query::Base] The constructed query object.
      def build_query(body)
        query = case body
        when Symbol
          raise "Cannot find scope :#{body} on #{resource_class}" unless resource_class.respond_to?(body)

          Plutonium::Query::ModelScope.new(body)
        when Proc
          Plutonium::Query::AdhocBlock.new(body)
        when Plutonium::Query::Filter
          body
        else
          raise NotImplementedError, "Unsupported query body: #{body.class} -> #{body}"
        end

        yield query if block_given?
        query
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
          query_params[:sort_directions][sort] = (sort_direction == "ASC") ? "DESC" : "ASC"
          # else
          #   query_params[:sort_fields].delete_if { |e| e == sort.to_s }
          #   query_params[:sort_directions].delete(sort)
          # end
        end
      end

      # Applies the defined sorters to the given scope.
      #
      # @param scope [Object] The initial scope.
      # @return [Object] The modified scope.
      def apply_sorts(scope)
        selected_sort_fields.each do |name|
          next unless (sorter = sort_definitions[name])

          params = {direction: selected_sort_directions[name] || "ASC"}
          scope = sorter.apply(scope, params)
        end
        scope
      end

      def apply_filters(scope)
        params = build_form(nil).extract_input(q: self.params)[:q]
        filter_definitions.each do |name, filter|
          name = name.to_sym
          filter_params = params[name].compact
          next if filter_params.blank?

          scope = filter.apply(scope, filter_params)
        end
        scope
      end
    end
  end
end
