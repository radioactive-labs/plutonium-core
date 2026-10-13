# frozen_string_literal: true

module Plutonium
  module Dashboard
    # The base class every dashboard subclasses.
    #
    #   class SalesDashboard < Plutonium::Dashboard::Base
    #     presents label: "Sales", description: "Orders and revenue at a glance"
    #     refresh 60
    #
    #     metric(:orders, icon: Phlex::TablerIcons::ShoppingCart) { orders.count }
    #     chart(:revenue, type: :area, span: 8) { orders.group_by_day(:created_at).sum(:total) }
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
        :registered_resources, :root_path, :current_package,
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

      # A filter's chosen value for this request, or its default.
      # @raise [ArgumentError] when the dashboard declares no such filter
      def filter_value(key)
        filter_values.fetch(key.to_sym) { raise ArgumentError, "#{self.class.name} declares no filter #{key.inspect}" }
      end

      # Every filter's chosen value, keyed by filter: what the page carries
      # onto each card's frame URL. Read once per request.
      def filter_values
        @filter_values ||= self.class.filters.to_h { |filter| [filter.key, filter.value_from(self)] }.freeze
      end

      # A filter's value => label pairs for this request, built once.
      def filter_choices(filter)
        (@filter_choices ||= {})[filter.key] ||= filter.choices_for(self)
      end

      # The resource's authorized scope with the scope chosen by its
      # `filter ..., scopes:` applied by the index's own query object, so a
      # card's number matches the index list {#filtered_url} opens. Without
      # such a filter, or with "All" chosen, the authorized scope as is.
      #
      # The scope block runs against this dashboard's controller, so it has
      # `current_user` and the portal's helpers, but not a resource
      # controller's (`current_parent`, `current_definition`, ...).
      def filtered(resource_class)
        relation = authorized_resource_scope(resource_class)
        name = chosen_scope(resource_class)
        return relation unless name

        scope_query_for(resource_class).scope_definitions.fetch(name).apply(relation, context: controller)
      end

      # The resource's index, on the scope chosen by its `filter ..., scopes:`.
      # "All" is sent explicitly when the definition has a `default_scope`, or
      # the index would apply that instead.
      def filtered_url(resource_class)
        name = chosen_scope(resource_class)
        scope = name || ("" if resource_definition_for(resource_class).default_scope)
        options = scope.nil? ? {} : {q: {scope:}}
        resource_url_for(resource_class, parent: nil, **options)
      end

      # The resource's definition in this dashboard's portal, falling back to
      # the base one, as a resource controller resolves it.
      def resource_definition_for(resource_class)
        (@resource_definitions ||= {})[resource_class] ||= begin
          portal_definition = current_package && "#{current_package}::#{resource_class}Definition".safe_constantize
          (portal_definition || "#{resource_class}Definition".constantize).new
        end
      end

      # The index's query object for the resource, holding its definition's
      # scopes: how each applies, whether it shows, and its label. It reads
      # no params and builds no URLs here.
      def scope_query_for(resource_class)
        (@scope_queries ||= {})[resource_class] ||=
          Plutonium::Resource::QueryObject.new(resource_class, {}, nil) do |query|
            resource_definition_for(resource_class).defined_scopes.each do |name, scope|
              query.define_scope name, scope[:block], **scope[:options]
            end
          end
      end

      # The toolbar links whose `condition:` passes for this request.
      def visible_links
        self.class.links.select { |link| link.visible?(self) }
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

      # The scope name a `filter ..., scopes: resource_class` has chosen, or
      # nil for "All" or when the dashboard has no such filter.
      def chosen_scope(resource_class)
        filter = self.class.filters.find { |candidate| candidate.resource_class == resource_class }
        return unless filter

        value = filter_value(filter.key)
        value unless value == Filter::ALL
      end

      def t(key, **options)
        Plutonium::Translation.t(key, **options)
      end
    end
  end
end
