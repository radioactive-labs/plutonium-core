module Plutonium
  module Reactor
    class ResourceQueryObject
      class << self
      end

      class Query
        include Plutonium::Core::Definers::InputDefiner

        def resource_class = nil
      end

      class ScopeQuery < Query
        attr_reader :name

        def initialize(name)
          @name = name
          yield self if block_given?
        end

        def apply(scope, params)
          if input_definitions.present?
            query_params = input_definitions.collect_all(params).symbolize_keys
            return scope if query_params.blank?
          else
            query_params = {}
          end

          scope.send name, **query_params
        end
      end

      class BlockQuery < Query
        attr_reader :body

        def initialize(body)
          @body = body
          yield self if block_given?
        end

        def apply(scope)
          scope.instance_exec(&block)
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
      end

      def build_url(**options)
        # base
        q = {}
        q = q.merge(search.input_definitions.collect_all(@params)) if search.present?
        q[:scope] = @params[:scope] if scope_definitions[@params[:scope]]

        # overrides
        q[:search] = options[:search] if options.key?(:search)
        q[:scope] = options[:scope] if options.key?(:scope)

        query_params = {q: q}.to_param
        "?#{query_params}"
      end

      def apply(scope)
        scope = search.apply(scope, @params) if search.present?
        scope = scope_definitions[@params[:scope]].apply(scope, @params) if scope_definitions[@params[:scope]].present?
        scope
      end

      def scope_definitions = @scope_definitions ||= {}.with_indifferent_access

      def filter_definitions = @filter_definitions ||= {}.with_indifferent_access

      private

      attr_reader :context

      def define_filters
        # define_filter :search, -> { where(name:) }
      end

      def define_scopes
        # s
      end

      def define_standard_queries
        define_search(:search) if resource_class.respond_to?(:search)
      end

      def define_filter(name, body = nil, &block)
        body ||= name
        filter_definitions[name] = build_query(body, &block)
      end

      def define_scope(name, body = nil, &block)
        body ||= name
        scope_definitions[name] = build_query(body, &block)
      end

      def define_search(body)
        @search = build_query(body) do |filter|
          filter.define_input :search
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
