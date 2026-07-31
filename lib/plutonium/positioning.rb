# frozen_string_literal: true

require "plutonium/positioning/config"
require "plutonium/positioning/model"

module Plutonium
  # Namespace for decimal/fractional ordering. Kanban-independent.
  #
  # This module is a pure namespace — it is never included into a model. The
  # AR mixin is Plutonium::Positioning::Model and the drag strategy object is
  # Plutonium::Positioning::Config.
  #
  # Pure math helpers are exposed as module-level methods so they can be
  # called without an AR instance:
  #   Plutonium::Positioning.position_between(1.0, 3.0)  # => 2.0
  #   Plutonium::Positioning.gap_exhausted?(1.0, 1.0)    # => true
  module Positioning
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

    # Migration helper that adds a position column pre-tuned for fractional
    # ordering. Mixed into ActiveRecord's table-definition classes by the
    # railtie, so it is available in both create_table and change_table:
    #
    #   create_table :tasks do |t|
    #     t.position                # decimal :position, precision: 16, scale: 8
    #     t.position :sort_order    # custom column name
    #     t.position index: true    # also add a single-column index
    #   end
    #
    #   change_table :tasks do |t|
    #     t.position
    #   end
    #
    # The precision/scale give midpoints ample headroom over the rebalance
    # threshold (EPSILON = 1e-6) — a too-small scale lets the last subdivision
    # round to a neighbor. Pass precision:/scale: to override.
    module MigrationHelpers
      DEFAULT_PRECISION = 16
      DEFAULT_SCALE = 8

      def position(name = :position, **options)
        column name, :decimal, precision: DEFAULT_PRECISION, scale: DEFAULT_SCALE, **options
      end
    end
  end
end
