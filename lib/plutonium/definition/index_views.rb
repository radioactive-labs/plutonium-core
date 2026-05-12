# frozen_string_literal: true

module Plutonium
  module Definition
    # DSL for declaring which index views a resource supports and how
    # they're configured.
    #
    # @example Enable both views, default to Grid
    #   class UserDefinition < Plutonium::Resource::Definition
    #     grid_fields(
    #       image:     :avatar,
    #       header:    :name,
    #       subheader: :email,
    #       meta:      [:role, :status]
    #     )
    #     default_index_view :grid
    #   end
    module IndexViews
      extend ActiveSupport::Concern

      KNOWN_VIEWS = %i[table grid].freeze
      GRID_SLOTS = %i[image header subheader body meta footer].freeze
      GRID_LAYOUTS = %i[compact media].freeze

      included do
        class_attribute :defined_index_views, default: [:table], instance_accessor: false
        class_attribute :defined_default_index_view, default: nil, instance_accessor: false
        class_attribute :defined_grid_fields, default: {}, instance_accessor: false
        class_attribute :defined_grid_layout, default: :compact, instance_accessor: false
        class_attribute :defined_grid_columns, default: nil, instance_accessor: false
      end

      class_methods do
        # Declares the index views this resource supports.
        # Usually unnecessary — declaring `grid_fields` auto-enables :grid
        # alongside the default :table. Use `index_views` only to disable
        # one (e.g. `index_views :grid` to drop the table view).
        # @param list [Array<Symbol>] one or more of {KNOWN_VIEWS}
        def index_views(*list)
          list = list.flatten.map(&:to_sym)
          invalid = list - KNOWN_VIEWS
          raise ArgumentError, "Unknown index_views: #{invalid.inspect}. Valid: #{KNOWN_VIEWS}" if invalid.any?
          self.defined_index_views = list.empty? ? [:table] : list
        end

        # Declares the default index view. Must be one of {.index_views}.
        # Falls back to the first declared view if unset.
        def default_index_view(name = nil)
          if name.nil?
            defined_default_index_view || defined_index_views.first
          else
            name = name.to_sym
            unless defined_index_views.include?(name)
              raise ArgumentError, "default_index_view #{name.inspect} not in index_views #{defined_index_views.inspect}"
            end
            self.defined_default_index_view = name
          end
        end

        # Maps grid slots to fields. Each slot is optional. Implicitly
        # adds `:grid` to {.index_views} so a resource can opt into the
        # Grid view simply by declaring its slots.
        # @param slots [Hash{Symbol => Symbol, Array<Symbol>}]
        def grid_fields(**slots)
          invalid = slots.keys - GRID_SLOTS
          raise ArgumentError, "Unknown grid slots: #{invalid.inspect}. Valid: #{GRID_SLOTS}" if invalid.any?
          self.defined_grid_fields = slots
          self.defined_index_views = defined_index_views + [:grid] unless defined_index_views.include?(:grid)
        end

        # Layout shape for grid cards. :compact (default) places the image
        # left of the content; :media stacks the image full-width on top.
        def grid_layout(value)
          value = value.to_sym
          unless GRID_LAYOUTS.include?(value)
            raise ArgumentError, "grid_layout must be one of #{GRID_LAYOUTS}, got #{value.inspect}"
          end
          self.defined_grid_layout = value
        end

        # Override responsive column count. Default is 1 / 2 / 3 / 4 at
        # sm / md / lg / xl.
        def grid_columns(value)
          self.defined_grid_columns = Integer(value)
        end
      end

      def defined_index_views = self.class.defined_index_views
      def default_index_view = self.class.default_index_view
      def defined_grid_fields = self.class.defined_grid_fields
      def defined_grid_layout = self.class.defined_grid_layout
      def defined_grid_columns = self.class.defined_grid_columns
    end
  end
end
