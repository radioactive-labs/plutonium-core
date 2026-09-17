# frozen_string_literal: true

module Plutonium
  module Dashboard
    # The base class every dashboard subclasses.
    #
    #   class SalesDashboard < Plutonium::Dashboard::Base
    #     presents label: "Sales", description: "Orders and revenue at a glance"
    #     columns 4
    #     refresh 60
    #
    #     metric(:orders, icon: Phlex::TablerIcons::ShoppingCart) { orders.count }
    #     chart(:revenue, type: :area, span: 2) { orders.group_by_day(:created_at).sum(:total) }
    #
    #     private
    #
    #     def orders = authorized_resource_scope(Order)
    #   end
    #
    # An instance is built per request with the view context, so card blocks
    # run with `current_user`, `current_scoped_entity`, `params`,
    # `authorized_resource_scope`, `resource_url_for` and the dashboard's own
    # methods in scope. `authorize?` gates the page and every card endpoint.
    class Base
      extend Plutonium::Translation::Lazy
      include Plutonium::Definition::Presentable
      include DSL

      attr_reader :view_context

      # Everything a card block is likely to reach for, forwarded to the view
      # context (which in turn exposes the controller's helper methods).
      delegate :current_user, :current_scoped_entity, :scoped_to_entity?,
        :params, :request, :controller, :current_engine,
        :resource_url_for, :authorized_resource_scope, :allowed_to?, :policy_for,
        :registered_resources, :root_path,
        to: :view_context

      class << self
        # `plutonium.dashboards.<key>` locale segment and frame/DOM prefix:
        # `AdminPortal::SalesDashboard` → `admin_portal/sales`.
        def i18n_key
          name.underscore.delete_suffix("_dashboard")
        end

        # Route slug used when `register_dashboard` gets no `as:` and mounts at
        # the root: `SalesDashboard` → `sales`.
        def route_name
          name.demodulize.underscore.delete_suffix("_dashboard")
        end

        # Title: `presents label:`, then the `plutonium.dashboards.<key>.label`
        # convention, then the class name minus "Dashboard".
        def label
          Plutonium::Translation.resolve(presentation_metadata[:label]) ||
            Plutonium::Translation.dashboard_text(self, :label) ||
            name.demodulize.delete_suffix("Dashboard").titleize
        end

        # Caption under the title: `presents description:`, then the
        # `plutonium.dashboards.<key>.description` convention.
        def description
          Plutonium::Translation.resolve(presentation_metadata[:description]) ||
            Plutonium::Translation.dashboard_text(self, :description)
        end

        # Sidebar icon: `presents icon:`, defaulting to a dashboard glyph.
        def icon
          presentation_metadata[:icon] || Phlex::TablerIcons::LayoutDashboard
        end
      end

      def initialize(view_context)
        @view_context = view_context
      end

      # Entry authorization. Authors override it; false → 403 on the page and
      # on every card endpoint. Default allow: a portal already sits behind
      # its auth constraint.
      def authorize? = true

      # The cards whose `condition:` passes for this request, in order.
      def visible_cards
        self.class.cards.select { |card| card.visible?(self) }
      end

      # The card the endpoint was asked for, if declared and visible.
      # @raise [UnknownCardError]
      def visible_card!(key)
        card = self.class.find_card!(key)
        raise UnknownCardError, "#{self.class.name} card #{key.inspect} is not visible" unless card.visible?(self)

        card
      end

      # The refresh interval for a card: its own, else the dashboard default.
      # A card declared `refresh: false` never refreshes.
      def refresh_for(card)
        return nil if card.refresh == false

        card.refresh || self.class.refresh
      end

      # The view context, for helpers a card block wants by name
      # (`helpers.number_to_currency`, route helpers, ...).
      def helpers = view_context

      private

      def t(key, **options)
        Plutonium::Translation.t(key, **options)
      end
    end
  end
end
