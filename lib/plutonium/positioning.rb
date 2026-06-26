# frozen_string_literal: true

module Plutonium
  # Standalone decimal/fractional ordering. Kanban-independent.
  #
  # Including this concern and calling `positioned_on` gives a model:
  # - automatic position assignment on create (appends to the end of its scope group)
  # - `reposition!(prev_record:, next_record:)` for drag-and-drop reordering
  # - `backfill_positions!` class method to number existing rows
  #
  # Pure math helpers are exposed as module-level methods so they can be
  # called without an AR instance:
  #   Plutonium::Positioning.position_between(1.0, 3.0)  # => 2.0
  #   Plutonium::Positioning.gap_exhausted?(1.0, 1.0)    # => true
  module Positioning
    extend ActiveSupport::Concern

    EPSILON = 1e-6

    # Returns the position that sits between +prev_val+ and +next_val+.
    #
    # Rules:
    #   both nil  → 0.0            (first item in an empty list)
    #   prev nil  → next_val - 1   (prepend)
    #   next nil  → prev_val + 1   (append)
    #   else      → midpoint
    def self.position_between(prev_val, next_val)
      return 0.0 if prev_val.nil? && next_val.nil?
      return next_val - 1 if prev_val.nil?
      return prev_val + 1 if next_val.nil?
      (prev_val + next_val) / 2.0
    end

    # Returns true when +prev_val+ and +next_val+ are so close together
    # that inserting a new midpoint would produce a duplicate.
    def self.gap_exhausted?(prev_val, next_val)
      return false if prev_val.nil? || next_val.nil?
      (next_val - prev_val).abs < EPSILON
    end

    included do
      class_attribute :positioning_column, instance_accessor: false, default: :position
      class_attribute :positioning_scope_attr, instance_accessor: false, default: nil
    end

    class_methods do
      # Opt in to positional ordering.
      #
      #   positioned_on :position, scope: :status
      #
      # @param column [Symbol] the decimal column that stores positions
      # @param scope  [Symbol, nil] group rows by this column; nil = single global group
      def positioned_on(column = :position, scope: nil)
        self.positioning_column = column
        self.positioning_scope_attr = scope
        before_create :assign_initial_position
      end

      # Number every row in the table per scope group as 1.0, 2.0, … in
      # +order+ order. Safe to call on an empty table.
      #
      # @param order [Symbol] column to sort by when assigning positions
      def backfill_positions!(order: :created_at)
        groups = positioning_scope_attr ? all.group_by(&positioning_scope_attr) : {nil => all.to_a}
        groups.each_value do |rows|
          ActiveRecord::Base.transaction do
            rows.sort_by { |r| r.public_send(order) }.each_with_index do |row, i|
              row.update_column(positioning_column, (i + 1).to_f)
            end
          end
        end
      end
    end

    # Move this record so it sits between +prev_record+ and +next_record+
    # within its scope group. Pass nil for either neighbor to move to an end.
    #
    # If the gap between the two neighbors is exhausted (too small to split)
    # the scope group is rebalanced first so that fresh integer positions are
    # available, then the record is positioned between the reloaded neighbors.
    #
    # @param prev_record [ActiveRecord::Base, nil]
    # @param next_record [ActiveRecord::Base, nil]
    def reposition!(prev_record:, next_record:)
      col = self.class.positioning_column
      prev_val = prev_record&.public_send(col)
      next_val = next_record&.public_send(col)
      if Plutonium::Positioning.gap_exhausted?(prev_val, next_val)
        rebalance_scope_group!
        prev_val = prev_record&.reload&.public_send(col)
        next_val = next_record&.reload&.public_send(col)
      end
      update!(col => Plutonium::Positioning.position_between(prev_val, next_val))
    end

    private

    def assign_initial_position
      col = self.class.positioning_column
      return if public_send(col).present?
      max = positioning_group_relation.maximum(col) || 0.0
      public_send(:"#{col}=", max + 1)
    end

    def positioning_group_relation
      rel = self.class.all
      attr = self.class.positioning_scope_attr
      attr ? rel.where(attr => public_send(attr)) : rel
    end

    def rebalance_scope_group!
      col = self.class.positioning_column
      ActiveRecord::Base.transaction do
        positioning_group_relation.order(col).each_with_index do |row, i|
          row.update_column(col, (i + 1).to_f)
        end
      end
    end
  end
end
