module Plutonium
  module Resource
    class QueryObject
      attr_reader :search_filter, :search_query
      attr_accessor :default_sort_config, :default_scope_name

      # Initializes a QueryObject with the given resource_class and parameters.
      #
      # @param resource_class [Object] The resource class.
      # @param params [Hash] The parameters for initialization.
      def initialize(resource_class, params, request_path, &)
        @resource_class = resource_class
        @params = params
        @request_path = request_path

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
      def define_scope(name, body = nil, **)
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

      # Builds a URL with the given options for search and sorting.
      #
      # @param options [Hash] The options for building the URL.
      # @option options [Boolean] :replace When true, clears all existing sorts before applying the new one
      # @return [String] The constructed URL with query parameters.
      def build_url(**options)
        q = {}

        q[:search] = options.key?(:search) ? options[:search].presence : search_query
        q[:scope] = if options.key?(:scope)
          options[:scope].presence
        else
          selected_scope_filter
        end

        if options.delete(:replace)
          q[:sort_directions] = {}
          q[:sort_fields] = []
        else
          q[:sort_directions] = selected_sort_directions.dup
          q[:sort_fields] = selected_sort_fields.dup
        end
        handle_sort_options!(q, options)

        filter_keys = filter_definitions.keys.map(&:to_sym)
        filter_overrides = options.slice(*filter_keys).stringify_keys
        q.merge! params.with_indifferent_access.slice(*filter_definitions.keys)
        q.merge!(filter_overrides)
        compacted = deep_compact({q: q})

        # Preserve explicit "All" selection (scope: nil in options means show all)
        if options.key?(:scope) && options[:scope].nil?
          compacted[:q] ||= {}
          compacted[:q][:scope] = ""
        end

        query_params = compacted.to_param
        "#{@request_path}?#{query_params}"
      end

      # Applies the defined filters and sorts to the given scope.
      #
      # @param scope [Object] The initial scope to which filters and sorts are applied.
      # @param params [Hash] The query parameters.
      # @param context [Object] Optional context (e.g., controller) for executing scope blocks.
      # @return [Object] The modified scope.
      def apply(scope, params, context: nil)
        params = deep_compact(params.with_indifferent_access)
        scope = search_filter.apply(scope, search: params[:search]) if search_filter && params[:search]
        # Use selected_scope which includes the default when no explicit selection
        effective_scope = @selected_scope_filter
        scope = scope_definitions[effective_scope].apply(scope, context:) if effective_scope && scope_definitions[effective_scope]
        scope = apply_sorts(scope, params)
        apply_filters(scope, params)
      end

      def scope_definitions = @scope_definitions ||= {}.with_indifferent_access

      # Returns true if user explicitly selected "All" scope (no filtering)
      def all_scope_selected? = @all_scope_selected

      # Returns the currently selected scope (may be default if none explicitly selected)
      def selected_scope = @selected_scope_filter

      def filter_definitions = @filter_definitions ||= {}.with_indifferent_access

      def sort_definitions = @sort_definitions ||= {}.with_indifferent_access

      # Returns an array of hashes describing each currently active filter.
      # Each hash has: name, label, value_label, clear_url
      def active_filter_descriptions
        filter_definitions.filter_map do |name, filter|
          name = name.to_sym
          filter_params = params[name]
          next unless filter_params.present?

          value_label = case filter_params
          when Hash, ActionController::Parameters
            entries = filter_params.to_h.reject { |_, v| v.blank? }
            next if entries.empty?
            # Single-input filters defer to the filter's `humanize_value`
            # (e.g. Association resolves ids to labels, Boolean translates
            # "true" -> "Yes"). Multi-input filters keep input-name
            # qualifiers (e.g. "from 2024, to 2025").
            if entries.size == 1
              humanized = filter.humanize_value(entries.values.first)
              next if humanized.blank?
              humanized
            else
              entries.map { |k, v| "#{k.to_s.humanize.downcase} #{v}" }.join(", ")
            end
          when Array
            entries = filter_params.reject(&:blank?)
            next if entries.empty?
            humanized = filter.humanize_value(entries)
            next if humanized.blank?
            humanized
          else
            next if filter_params.to_s.blank?
            humanized = filter.humanize_value(filter_params)
            next if humanized.blank?
            humanized
          end

          {
            name: name,
            label: name.to_s.humanize,
            value_label: value_label,
            clear_url: build_url(name => nil)
          }
        end
      end

      # Provides sorting parameters for the given field name.
      #
      # @param name [Symbol, String] The name of the field to sort.
      # @return [Hash, nil] The sorting parameters including URL, multi_url, direction, position and multi flag.
      def sort_params_for(name)
        return unless sort_definitions[name]

        multi = selected_sort_fields.size > 1 && selected_sort_fields.include?(name.to_s)

        {
          url: build_url(sort: name, replace: true),
          multi_url: build_url(sort: name),
          reset_url: build_url(sort: name, reset: true),
          position: selected_sort_fields.index(name.to_s),
          direction: selected_sort_directions[name],
          multi: multi
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
        @search_query = params[:search].presence&.strip
        # Track if user explicitly selected "all" (scope param present but blank)
        @all_scope_selected = params.key?(:scope) && params[:scope].blank?
        @selected_scope_filter = if @all_scope_selected
          nil  # User clicked "All"
        else
          params[:scope].presence || default_scope_name
        end
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
        if resource_class.column_names.include?(name.to_s)
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
        params[:sort_directions]&.slice(*sort_definitions.keys.map(&:to_sym)) || {}
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
      def apply_sorts(scope, params)
        selected_sort_directions = extract_sort_directions(params)

        if selected_sort_fields.any?
          # Apply user-selected sorts
          selected_sort_fields.each do |name|
            next unless (sorter = sort_definitions[name])

            direction = selected_sort_directions[name] || "ASC"
            scope = sorter.apply(scope, direction:)
          end
        elsif default_sort_config
          # Apply default sort when no sorts are selected
          scope = apply_default_sort(scope)
        end

        scope
      end

      def apply_filters(scope, params)
        filter_definitions.each do |name, filter|
          name = name.to_sym
          filter_params = params[name]
          next if filter_params.blank?

          scope = filter.apply(scope, **filter_params.symbolize_keys)
        end
        scope
      end

      def deep_compact(hash)
        hash.transform_values do |value|
          if value.respond_to?(:transform_values)
            deep_compact(value).presence
          else
            value.presence
          end
        end.compact
      end

      # Applies the default sort to the given scope
      #
      # @param scope [Object] The initial scope
      # @return [Object] The sorted scope
      def apply_default_sort(scope)
        case default_sort_config
        when Proc
          # Block form: default_sort { |scope| scope.order(...) }
          default_sort_config.call(scope)
        when Array
          # Field/direction form: default_sort :created_at, :desc
          field, direction = default_sort_config
          scope.order(field => direction)
        else
          scope
        end
      end
    end
  end
end
