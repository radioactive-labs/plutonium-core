# frozen_string_literal: true

module Plutonium
  module Dashboard
    # One declared card: its kind (`:metric`, `:chart` or `:custom`), the
    # presentation options every kind shares, the kind-specific options and
    # the block that produces its data (or, for a custom card, its markup).
    #
    # Built by {DSL} at class-load and frozen; everything request-dependent
    # (label translation, `condition:`, `href:`) is resolved per render.
    class Card
      KINDS = %i[metric chart custom].freeze

      # Grid columns a card may span. `:full` always spans the whole row.
      SPANS = [1, 2, 3, 4, 5, 6, :full].freeze

      METRIC_FORMATS = %i[number currency percentage human].freeze
      METRIC_POSITIVE = %i[up down].freeze
      CHART_TYPES = %i[line area column bar pie donut scatter].freeze

      # Options every kind accepts.
      COMMON_OPTIONS = %i[label description icon span lazy refresh condition href].freeze
      METRIC_OPTIONS = %i[format precision unit prefix suffix positive change_label].freeze
      CHART_OPTIONS = %i[type height].freeze

      attr_reader :key, :kind, :icon, :span, :refresh, :condition, :href, :block, :options, :dashboard_class

      def initialize(key, kind:, dashboard_class:, block:, **options)
        @key = key.to_sym
        @kind = kind
        @dashboard_class = dashboard_class
        @block = block

        raise ArgumentError, "card #{@key.inspect}: unknown kind #{kind.inspect}" unless KINDS.include?(kind)
        raise ArgumentError, "card #{@key.inspect} requires a block" if block.nil?

        common = options.slice(*COMMON_OPTIONS)
        specific = options.except(*COMMON_OPTIONS)

        @label = common[:label]
        @description = common[:description]
        @icon = common[:icon]
        @span = validate_span!(common.fetch(:span, 1))
        @lazy = common.fetch(:lazy, true) ? true : false
        @refresh = validate_refresh!(common[:refresh])
        @condition = common[:condition]
        @href = common[:href]
        @options = validate_options!(specific).freeze

        if @refresh && !@lazy
          raise ArgumentError,
            "card #{@key.inspect}: `refresh:` reloads the card's turbo frame, so it needs `lazy: true` (the default)"
        end

        freeze
      end

      def lazy? = @lazy
      def metric? = kind == :metric
      def chart? = kind == :chart
      def custom? = kind == :custom
      def full_width? = span == :full

      # The card title, resolved per request: an explicit `label:` (lazy `t`
      # procs included), then the `plutonium.dashboards.<dashboard>.cards.<key>.label`
      # convention, then the key titleized.
      def label
        Plutonium::Translation.resolve(@label) ||
          Plutonium::Translation.dashboard_text(dashboard_class, :cards, key, :label) ||
          key.to_s.titleize
      end

      # Optional caption; `description:` first, then the locale convention.
      def description
        Plutonium::Translation.resolve(@description) ||
          Plutonium::Translation.dashboard_text(dashboard_class, :cards, key, :description)
      end

      # Whether the card renders for this request. `condition:` is a proc
      # evaluated on the dashboard instance (zero arity) or with it as the
      # argument (one arity), or a symbol naming a dashboard method. It gates
      # the page AND the card endpoint, so a hidden card cannot be fetched
      # directly.
      def visible?(dashboard)
        return true if condition.nil?

        result = case condition
        when Symbol then dashboard.send(condition)
        when Proc then evaluate_on(dashboard, condition)
        else condition
        end
        result ? true : false
      end

      # The card's link target for this request, if any.
      def href_for(dashboard)
        href.is_a?(Proc) ? evaluate_on(dashboard, href) : href
      end

      # Runs the data block on the dashboard instance.
      def evaluate(dashboard)
        evaluate_on(dashboard, block)
      end

      # DOM id of the turbo frame hosting this card. One dashboard renders per
      # page, so the card key is unique enough.
      def frame_id
        "#{FRAME_PREFIX}-#{key.to_s.dasherize}"
      end

      # Chart cards: the Chartkick constructor name for `type:`.
      def chart_class
        case options[:type]
        when :area then "AreaChart"
        when :column then "ColumnChart"
        when :bar then "BarChart"
        when :pie, :donut then "PieChart"
        when :scatter then "ScatterChart"
        else "LineChart"
        end
      end

      # Chart cards: Chartkick options passed through to the JS constructor,
      # with the `donut` flag derived from `type: :donut`.
      def chart_options
        passthrough = options.except(*CHART_OPTIONS)
        passthrough = passthrough.merge(donut: true) if options[:type] == :donut
        passthrough
      end

      private

      def evaluate_on(dashboard, callable)
        callable.arity.zero? ? dashboard.instance_exec(&callable) : dashboard.instance_exec(dashboard, &callable)
      end

      def validate_span!(span)
        return span if SPANS.include?(span)

        raise ArgumentError, "card #{key.inspect}: span must be one of #{SPANS.inspect}, got #{span.inspect}"
      end

      def validate_refresh!(refresh)
        return nil if refresh.nil?
        return refresh.to_i if refresh.respond_to?(:to_i) && refresh.to_i.positive?

        raise ArgumentError, "card #{key.inspect}: refresh must be a positive number of seconds, got #{refresh.inspect}"
      end

      def validate_options!(specific)
        case kind
        when :metric then validate_metric_options!(specific)
        when :chart then validate_chart_options!(specific)
        else validate_custom_options!(specific)
        end
      end

      def validate_metric_options!(specific)
        unknown = specific.keys - METRIC_OPTIONS
        raise ArgumentError, "metric #{key.inspect}: unknown option(s) #{unknown.inspect}" if unknown.any?

        format = specific[:format]
        unless format.nil? || format.is_a?(Proc) || METRIC_FORMATS.include?(format)
          raise ArgumentError,
            "metric #{key.inspect}: format must be one of #{METRIC_FORMATS.inspect} or a proc, got #{format.inspect}"
        end

        positive = specific.fetch(:positive, :up)
        unless METRIC_POSITIVE.include?(positive)
          raise ArgumentError, "metric #{key.inspect}: positive must be :up or :down, got #{positive.inspect}"
        end

        specific.merge(positive:)
      end

      def validate_chart_options!(specific)
        type = specific.fetch(:type, :line)
        unless CHART_TYPES.include?(type)
          raise ArgumentError, "chart #{key.inspect}: type must be one of #{CHART_TYPES.inspect}, got #{type.inspect}"
        end

        specific.merge(type:, height: specific.fetch(:height, "240px"))
      end

      def validate_custom_options!(specific)
        raise ArgumentError, "card #{key.inspect}: unknown option(s) #{specific.keys.inspect}" if specific.any?

        specific
      end
    end
  end
end
