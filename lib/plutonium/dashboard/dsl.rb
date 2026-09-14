# frozen_string_literal: true

module Plutonium
  module Dashboard
    # The author-facing class macros: `metric`, `chart`, `card`, `columns`,
    # `refresh` and `width`. Mixed into {Base}.
    module DSL
      extend ActiveSupport::Concern

      UNSET = Object.new
      private_constant :UNSET

      DEFAULT_COLUMNS = 3
      MAX_COLUMNS = 6

      class_methods do
        # The declared cards, in declaration order.
        def cards
          @cards ||= []
        end

        # A single number with an optional change indicator. The block returns
        # the value, or a hash: `{value:, previous:}` / `{value:, change:, trend:}`.
        #
        #   metric(:orders, icon: Phlex::TablerIcons::ShoppingCart) { Order.count }
        #   metric(:revenue, format: :currency, positive: :up) do
        #     {value: Order.this_month.sum(:total), previous: Order.last_month.sum(:total)}
        #   end
        def metric(key, **options, &block)
          add_card(key, kind: :metric, options:, block:)
        end

        # A Chartkick chart. The block returns Chartkick data: a `{label => value}`
        # hash, an array of pairs, or an array of `{name:, data:}` series. Options
        # other than `type:` / `height:` and the common card options are passed
        # straight through to Chartkick (`colors:`, `stacked:`, `suffix:`, ...).
        #
        #   chart(:signups, type: :line, span: 2) { User.group_by_day(:created_at, last: 30).count }
        def chart(key, **options, &block)
          add_card(key, kind: :chart, options:, block:)
        end

        # A free-form card. The block renders Phlex markup inside the card body
        # and can call the dashboard's own methods.
        #
        #   card(:recent, span: :full) do
        #     ul { dashboard.recent_orders.each { |o| li { o.number } } }
        #   end
        def card(key, **options, &block)
          add_card(key, kind: :custom, options:, block:)
        end

        # Grid columns on large screens (1..6, default 3). Cards `span:` up to
        # this many columns.
        def columns(count = UNSET)
          return @columns || DEFAULT_COLUMNS if count.equal?(UNSET)

          unless count.is_a?(Integer) && count.between?(1, MAX_COLUMNS)
            raise ArgumentError, "columns must be an integer between 1 and #{MAX_COLUMNS}, got #{count.inspect}"
          end

          @columns = count
        end

        # Default refresh interval (seconds) for every lazy card. A card's own
        # `refresh:` overrides it; `refresh false` on a card opts out.
        def refresh(seconds = UNSET)
          return @refresh if seconds.equal?(UNSET)

          valid = seconds.nil? || (seconds.respond_to?(:to_i) && seconds.to_i.positive?)
          raise ArgumentError, "refresh must be a positive number of seconds or nil, got #{seconds.inspect}" unless valid

          @refresh = seconds&.to_i
        end

        # Page width, one of {Plutonium::UI::PageWidth::SIZES}. Defaults to
        # `:full`: a card grid wants the room an index page gets, not the
        # reading column detail pages are constrained to.
        def width(value = UNSET)
          return @width || :full if value.equal?(UNSET)

          @width = Plutonium::UI::PageWidth.validate!(value)
        end

        # @return [Card, nil]
        def find_card(key)
          key = key.to_s
          cards.find { |card| card.key.to_s == key }
        end

        # @return [Card]
        # @raise [UnknownCardError] when no card has that key
        def find_card!(key)
          find_card(key) || raise(UnknownCardError, "#{name} declares no card #{key.inspect}")
        end

        private

        def add_card(key, kind:, options:, block:)
          key = key.to_sym
          if find_card(key)
            raise ArgumentError, "#{name || "dashboard"} already declares a card #{key.inspect}"
          end

          cards << Card.new(key, kind:, dashboard_class: self, block:, **options)
          cards.last
        end

        # Class-level state must not leak into subclasses by reference.
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@cards, cards.dup)
          subclass.instance_variable_set(:@columns, @columns)
          subclass.instance_variable_set(:@refresh, @refresh)
          subclass.instance_variable_set(:@width, @width)
        end
      end
    end
  end
end
