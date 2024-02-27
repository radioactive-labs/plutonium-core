module Plutonium
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

      attr_reader :search

      def initialize(context, params)
        @context = context

        params = params.dup.permit!.to_h if params.is_a?(ActionController::Parameters)
        @params = params || {}

        define_standard_queries
        define_scopes
        define_filters
        define_sorters
      end

      def build_url(**options)
        # base
        q = {}
        q = q.merge(search.input_definitions.collect_all(@params)) if search.present?
        q[:scope] = @params[:scope] if scope_definitions[@params[:scope]]
        q[:sort_directions] = @params[:sort_directions].dup if @params[:sort_directions].present?
        q[:sort_fields] = selected_sorters.dup if selected_sorters.present?

        # overrides
        q[:search] = options[:search] if options.key?(:search)
        q[:scope] = options[:scope] if options.key?(:scope)

        if (sort = options[:sort])
          q[:sort_fields] ||= []
          q[:sort_directions] ||= {}

          q[:sort_fields] << sort.to_s unless q[:sort_fields].include?(sort.to_s)

          sort_direction = @params[:sort_directions].try(:[], sort)&.upcase

          if sort_direction.nil?
            q[:sort_directions][sort] = "ASC"
          elsif sort_direction == "ASC"
            q[:sort_directions][sort] = "DESC"
          else
            q[:sort_directions].delete sort
            q[:sort_fields].delete_if { |e| e == sort.to_s }
          end
        end

        "?#{{q: q}.to_param}"
      end

      def apply(scope)
        scope = search.apply(scope, @params) if search.present?
        scope = scope_definitions[@params[:scope]].apply(scope, @params) if scope_definitions[@params[:scope]].present?
        selected_sorters.each do |name|
          sorter = sort_definitions[name]
          next unless sorter.present?

          params = {direction: @params[:sort_directions].try(:[], name)}
          scope = sorter.apply(scope, params)
        end
        scope
      end

      def scope_definitions = @scope_definitions ||= {}.with_indifferent_access

      def filter_definitions = @filter_definitions ||= {}.with_indifferent_access

      def sort_definitions = @sort_definitions ||= {}.with_indifferent_access

      def sort_params_for(name)
        return unless sort_definitions[name]

        # TODO: refactor this. make it cleaner and adhere to sortinng param invariants
        {
          url: build_url(sort: name),
          position: selected_sorters.index(name.to_s),
          direction: @params[:sort_directions].try(:[], name)
        }
      end

      private

      attr_reader :context

      def selected_sorters
        @selected_sorters ||= @params[:sort_fields] || []
      end

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
          sort_field = if resource_class.content_column_field_names.include? name
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
        @search = build_query(body) do |query|
          query.define_input :search
        end
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
