# frozen_string_literal: true

module Plutonium
  module Dashboard
    # A page-level control every card reads, declared with `filter`. Its value
    # comes from the request's query string under the filter's key, and a value
    # that is not one of the choices reads as the default, so a hand-edited URL
    # can never reach a card block.
    #
    # The choices are either given (`choices:`) or are a resource's scopes
    # (`scopes: Post`): "All" plus every scope the resource's definition
    # declares, labelled and gated the way the index's scope pills are.
    class Filter
      # Keys a filter cannot take: the card route's own params and the options
      # `url_for` reads, all of which the filter values are merged into when
      # building each card's frame URL. A key that is a path segment of the
      # mount (an entity scope, a `(:locale)` scope) is refused per request,
      # since only the route knows it.
      RESERVED_KEYS = %i[
        card dashboard_class controller action format anchor params path_params
        host protocol port subdomain domain tld_length user password
        script_name original_script_name only_path trailing_slash
        use_route _recall
      ].freeze

      # The value of a scope filter's "All" choice.
      ALL = "all"

      attr_reader :key, :resource_class

      # @param choices [Hash{#to_s => String, Proc}, nil] value => label, in display order
      # @param scopes [Class, nil] a resource whose definition's scopes are the choices
      # @param default [#to_s, nil] one of the choices; the first (or, for
      #   scopes, the definition's `default_scope`, else "All") when nil
      def initialize(key, choices: nil, scopes: nil, default: nil, label: nil)
        @key = key.to_sym
        if RESERVED_KEYS.include?(@key)
          raise ArgumentError, "filter #{@key.inspect}: the name is reserved by the card route, pick another"
        end
        unless choices.nil? ^ scopes.nil?
          raise ArgumentError, "filter #{@key.inspect}: pass exactly one of choices: or scopes:"
        end

        @label = label
        @default = default&.to_s

        if scopes
          raise ArgumentError, "filter #{@key.inspect}: scopes: takes a resource class, got #{scopes.inspect}" unless scopes.is_a?(Class)

          @resource_class = scopes
        else
          @choices = choices.to_h.transform_keys(&:to_s).freeze
          raise ArgumentError, "filter #{@key.inspect}: choices must not be empty" if @choices.empty?

          @default ||= @choices.keys.first
          validate_default!(@choices)
        end
      end

      def scopes? = !@resource_class.nil?

      # The control's accessible name.
      def label
        Plutonium::Translation.resolve(@label) || key.to_s.humanize
      end

      # value => label for this request. Labels may be lazy `t` procs. Read it
      # through {Base#filter_choices}, which builds it once per request.
      def choices_for(dashboard)
        scopes? ? scope_choices(dashboard) : @choices
      end

      def default_for(dashboard)
        return @default unless scopes?

        default = @default || dashboard.resource_definition_for(resource_class).default_scope&.to_s || ALL
        validate_default!(dashboard.filter_choices(self), default)
        default
      end

      # The chosen value for this request.
      def value_from(dashboard)
        value = dashboard.params[key].to_s
        dashboard.filter_choices(self).key?(value) ? value : default_for(dashboard)
      end

      private

      def scope_choices(dashboard)
        definition = dashboard.resource_definition_for(resource_class)
        condition_context = Plutonium::Action::ConditionContext.new(dashboard.view_context, nil)
        visible = definition.defined_scopes.select do |_name, config|
          condition = config[:options][:condition]
          condition.nil? || condition_context.instance_exec(&condition)
        end

        {ALL => -> { Plutonium::Translation.t("plutonium.ui.table.all") }}.merge(
          visible.to_h do |name, _config|
            [name.to_s, Plutonium::Translation.label_for(:scope, resource_class, name) || name.to_s.humanize]
          end
        )
      end

      def validate_default!(choices, default = @default)
        return if choices.key?(default)

        raise ArgumentError, "filter #{key.inspect}: default #{default.inspect} is not one of #{choices.keys.inspect}"
      end
    end
  end
end
