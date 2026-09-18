# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Dashboard
    class DslTest < Minitest::Test
      class FakeUser
        attr_reader :email

        def initialize(email) = @email = email
      end

      # A stand-in for the view context: only what the dashboard delegates.
      class FakeViewContext
        attr_reader :current_user

        def initialize(current_user: nil) = @current_user = current_user
      end

      class SalesDashboard < Plutonium::Dashboard::Base
        presents label: "Sales", description: "Money in"
        refresh 120

        metric(:orders) { 10 }
        metric(:revenue, format: :currency, unit: "€", precision: 0, refresh: 30) { {value: 1200, previous: 1000} }
        chart(:trend, type: :area, span: 8, colors: ["#000"], stacked: true) { {"a" => 1} }
        chart(:split, type: :donut, refresh: false) { {} }
        card(:notes, span: :full, lazy: false, condition: -> { current_user.present? }) { p { "hi" } }
        metric(:admin_only, condition: :admin?) { 1 }

        def admin? = current_user&.email == "admin@example.com"
      end

      class NarrowDashboard < SalesDashboard
        refresh 15
        metric(:extra) { 0 }
      end

      def dashboard(user = nil)
        SalesDashboard.new(FakeViewContext.new(current_user: user))
      end

      def test_cards_keep_declaration_order_and_kinds
        assert_equal %i[orders revenue trend split notes admin_only], SalesDashboard.cards.map(&:key)
        assert_equal %i[metric metric chart chart custom metric], SalesDashboard.cards.map(&:kind)
      end

      def test_presents_label_and_description
        assert_equal "Sales", SalesDashboard.label
        assert_equal "Money in", SalesDashboard.description
        assert_equal Phlex::TablerIcons::LayoutDashboard, SalesDashboard.icon
      end

      def test_label_falls_back_to_the_class_name_without_the_suffix
        klass = Class.new(Plutonium::Dashboard::Base)
        klass.define_singleton_method(:name) { "Reporting::WeeklySummaryDashboard" }

        assert_equal "Weekly Summary", klass.label
        assert_equal "reporting/weekly_summary", klass.i18n_key
        assert_equal "weekly_summary", klass.route_name
        assert_nil klass.description
      end

      def test_refresh_and_width_defaults
        klass = Class.new(Plutonium::Dashboard::Base)
        assert_nil klass.refresh
        assert_equal :full, klass.width

        assert_equal 120, SalesDashboard.refresh
      end

      def test_refresh_and_width_reject_bad_values
        klass = Class.new(Plutonium::Dashboard::Base)
        assert_raises(ArgumentError) { klass.refresh(-1) }
        assert_raises(ArgumentError) { klass.width(:huge) }
      end

      def test_subclass_gets_its_own_copy_of_the_configuration
        assert_equal %i[orders revenue trend split notes admin_only extra], NarrowDashboard.cards.map(&:key)
        assert_equal 15, NarrowDashboard.refresh
        refute_includes SalesDashboard.cards.map(&:key), :extra
        assert_equal 120, SalesDashboard.refresh
      end

      def test_card_defaults
        card = SalesDashboard.find_card(:orders)
        assert_equal 3, card.span
        assert card.lazy?
        assert_nil card.refresh
        assert_nil card.condition
        assert_equal "Orders", card.label
        assert_nil card.description
        assert_equal "pu-dashboard-card-orders", card.frame_id
      end

      # The grid is 12 columns wide. A kind's default span is the width it
      # reads well at: four metrics, two charts or two custom cards to a row.
      def test_each_kind_has_its_own_default_span
        klass = Class.new(Plutonium::Dashboard::Base)
        klass.metric(:m) { 1 }
        klass.chart(:c, type: :line) { {} }
        klass.card(:k) { nil }

        assert_equal 3, klass.find_card(:m).span
        assert_equal 6, klass.find_card(:c).span
        assert_equal 6, klass.find_card(:k).span
      end

      def test_span_is_one_to_twelve_columns_or_full
        klass = Class.new(Plutonium::Dashboard::Base)
        klass.metric(:narrow, span: 1) { 1 }
        klass.metric(:wide, span: 12) { 1 }
        klass.metric(:full, span: :full) { 1 }

        assert_equal 1, klass.find_card(:narrow).span
        assert_equal 12, klass.find_card(:wide).span
        assert_equal 12, klass.find_card(:full).span
        assert klass.find_card(:full).full_width?
        refute klass.find_card(:narrow).full_width?

        assert_raises(ArgumentError) { klass.metric(:a, span: 0) { 1 } }
        assert_raises(ArgumentError) { klass.metric(:a, span: 13) { 1 } }
        assert_raises(ArgumentError) { klass.metric(:a, span: 2.5) { 1 } }
        assert_raises(ArgumentError) { klass.metric(:a, span: :half) { 1 } }
      end

      def test_columns_is_gone
        klass = Class.new(Plutonium::Dashboard::Base)
        assert_raises(NoMethodError) { klass.columns 4 }
      end

      def test_duplicate_card_keys_raise
        klass = Class.new(Plutonium::Dashboard::Base)
        klass.metric(:a) { 1 }
        err = assert_raises(ArgumentError) { klass.metric(:a) { 2 } }
        assert_match(/already declares a card :a/, err.message)
      end

      def test_a_card_needs_a_block
        klass = Class.new(Plutonium::Dashboard::Base)
        assert_raises(ArgumentError) { klass.metric(:a) }
      end

      def test_metric_options_are_validated
        klass = Class.new(Plutonium::Dashboard::Base)
        assert_raises(ArgumentError) { klass.metric(:a, format: :bogus) { 1 } }
        assert_raises(ArgumentError) { klass.metric(:a, positive: :sideways) { 1 } }
        assert_raises(ArgumentError) { klass.metric(:a, colors: []) { 1 } }
        assert_raises(ArgumentError) { klass.metric(:a, refresh: 0) { 1 } }
        assert_raises(ArgumentError) { klass.metric(:a, refresh: 10, lazy: false) { 1 } }

        card = SalesDashboard.find_card(:revenue)
        assert_equal({format: :currency, unit: "€", precision: 0, positive: :up}, card.options)
        assert_equal 30, card.refresh
      end

      def test_chart_options_pass_through_to_chartkick
        card = SalesDashboard.find_card(:trend)
        assert_equal "AreaChart", card.chart_class
        assert_equal({colors: ["#000"], stacked: true}, card.chart_options)
        assert_equal "240px", card.options[:height]
        assert_equal 8, card.span

        donut = SalesDashboard.find_card(:split)
        assert_equal "PieChart", donut.chart_class
        assert_equal({donut: true}, donut.chart_options)

        klass = Class.new(Plutonium::Dashboard::Base)
        assert_raises(ArgumentError) { klass.chart(:a, type: :radar) { {} } }
      end

      def test_custom_card_rejects_unknown_options
        klass = Class.new(Plutonium::Dashboard::Base)
        assert_raises(ArgumentError) { klass.card(:a, format: :number) { nil } }

        card = SalesDashboard.find_card(:notes)
        assert_equal 12, card.span
        assert card.full_width?
        refute card.lazy?
      end

      def test_find_card_bang_raises_for_unknown_keys
        assert_equal :orders, SalesDashboard.find_card!("orders").key
        assert_raises(UnknownCardError) { SalesDashboard.find_card!(:nope) }
      end

      def test_visible_cards_honour_proc_and_symbol_conditions
        assert_equal %i[orders revenue trend split], dashboard.visible_cards.map(&:key)

        member = dashboard(FakeUser.new("someone@example.com"))
        assert_equal %i[orders revenue trend split notes], member.visible_cards.map(&:key)

        admin = dashboard(FakeUser.new("admin@example.com"))
        assert_equal %i[orders revenue trend split notes admin_only], admin.visible_cards.map(&:key)
      end

      def test_visible_card_bang_rejects_hidden_cards
        assert_raises(UnknownCardError) { dashboard.visible_card!(:notes) }
        assert_equal :notes, dashboard(FakeUser.new("x@example.com")).visible_card!(:notes).key
      end

      def test_evaluate_runs_the_block_on_the_dashboard_instance
        klass = Class.new(Plutonium::Dashboard::Base) do
          metric(:via_method) { helper_value }
          metric(:via_arg) { |dash| dash.helper_value * 2 }

          def helper_value = 21
        end

        dash = klass.new(FakeViewContext.new)
        assert_equal 21, klass.find_card(:via_method).evaluate(dash)
        assert_equal 42, klass.find_card(:via_arg).evaluate(dash)
      end

      def test_href_can_be_static_or_resolved_on_the_dashboard
        klass = Class.new(Plutonium::Dashboard::Base) do
          metric(:static, href: "/orders") { 1 }
          metric(:dynamic, href: -> { "/users/#{current_user.email}" }) { 1 }
        end
        dash = klass.new(FakeViewContext.new(current_user: FakeUser.new("a@b.c")))

        assert_equal "/orders", klass.find_card(:static).href_for(dash)
        assert_equal "/users/a@b.c", klass.find_card(:dynamic).href_for(dash)
        assert_nil SalesDashboard.find_card(:orders).href_for(dashboard)
      end

      def test_refresh_for_prefers_the_card_then_the_dashboard
        assert_equal 30, dashboard.refresh_for(SalesDashboard.find_card(:revenue))
        assert_equal 120, dashboard.refresh_for(SalesDashboard.find_card(:orders))
      end

      def test_refresh_false_opts_a_card_out_of_the_dashboard_default
        card = SalesDashboard.find_card(:split)

        assert_equal false, card.refresh
        assert_nil dashboard.refresh_for(card)
      end

      def test_refresh_false_is_allowed_on_an_inline_card
        klass = Class.new(Plutonium::Dashboard::Base)
        klass.metric(:a, refresh: false, lazy: false) { 1 }

        assert_equal false, klass.find_card(:a).refresh
      end

      def test_authorize_defaults_to_true
        assert dashboard.authorize?
      end

      def test_lazy_translation_labels_resolve_per_render
        klass = Class.new(Plutonium::Dashboard::Base) do
          metric(:yes, label: t("plutonium.boolean.true")) { 1 }
        end
        assert_equal "Yes", klass.find_card(:yes).label
      end
    end
  end
end
