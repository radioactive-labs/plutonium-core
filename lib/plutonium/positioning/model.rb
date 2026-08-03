# frozen_string_literal: true

module Plutonium
  module Positioning
    # Standalone decimal/fractional ordering. Kanban-independent.
    #
    # Including this concern and calling `positioned_on` gives a model:
    # - automatic position assignment on create (appends to the end of its scope group)
    # - `reposition!(prev_record:, next_record:)` for drag-and-drop reordering
    # - `backfill_positions!` class method to number existing rows
    #
    # This lives one level below Plutonium::Positioning on purpose. A concern is
    # mixed into user models, and every constant nested in the included module
    # joins that model's constant lookup — so a concern named Positioning would
    # make a bare `Config` inside the model resolve to
    # Plutonium::Positioning::Config, silently shadowing the app's own ::Config.
    # Keeping the namespace and the mixin separate stops the leak.
    module Model
      extend ActiveSupport::Concern

      included do
        class_attribute :positioning_column, instance_accessor: false, default: :position
        class_attribute :positioning_scope_attr, instance_accessor: false, default: nil
        # Separate from positioning_column, which has a default and so cannot
        # answer "did this model actually call positioned_on?". Including the
        # concern without calling it skips `before_create :assign_initial_position`
        # entirely — every row keeps a nil position and the order is arbitrary —
        # so the definition DSL checks this flag, not mere inclusion.
        class_attribute :positioning_declared, instance_accessor: false, default: false
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
          self.positioning_declared = true
          before_create :assign_initial_position
        end

        # Number every row in the table per scope group as 1.0, 2.0, … in
        # +order+ order. Safe to call on an empty table.
        #
        # @param order [Symbol] column to sort by when assigning positions
        def backfill_positions!(order: :created_at)
          groups = positioning_scope_attr ? all.group_by(&positioning_scope_attr) : {nil => all.to_a}
          groups.each_value do |rows|
            # `transaction` on THIS class, never ActiveRecord::Base.transaction.
            # A transaction is opened on the receiver's connection pool; the
            # UPDATEs below go out on this model's pool (update_column →
            # self.class._update_record). For a model on a secondary database
            # those are two different connections: ActiveRecord::Base would BEGIN
            # on primary and do nothing else with it while every UPDATE
            # autocommits on the model's own connection — a crash halfway leaves
            # the group partly renumbered, with duplicate/gapped positions and
            # nothing to roll back. Do not "simplify" this back.
            transaction do
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
      # @return [Plutonium::Positioning::Result] whose `rebalanced?` tells the
      #   caller whether rows OTHER than this one moved — a drag-and-drop client
      #   that optimistically reordered its own view needs to re-sync when so.
      def reposition!(prev_record:, next_record:)
        col = self.class.positioning_column
        prev_val = prev_record&.public_send(col)
        next_val = next_record&.public_send(col)
        rebalanced = Plutonium::Positioning.gap_exhausted?(prev_val, next_val)
        if rebalanced
          rebalance_scope_group!
          prev_val = prev_record&.reload&.public_send(col)
          next_val = next_record&.reload&.public_send(col)
        end
        update!(col => Plutonium::Positioning.position_between(prev_val, next_val))
        Plutonium::Positioning::Result.new(rebalanced:)
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
        # self.class.transaction, never ActiveRecord::Base.transaction — the
        # BEGIN must land on the connection the UPDATEs below actually use. See
        # the note in backfill_positions!: on a secondary-database model the
        # ActiveRecord::Base form opens an empty transaction on primary and every
        # renumbering UPDATE autocommits unprotected, so a failure mid-rebalance
        # is unrecoverable. Rebalancing is exactly where that matters.
        self.class.transaction do
          positioning_group_relation.order(col).each_with_index do |row, i|
            row.update_column(col, (i + 1).to_f)
          end
        end
      end
    end
  end
end
