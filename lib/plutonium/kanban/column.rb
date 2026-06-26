# frozen_string_literal: true

module Plutonium
  module Kanban
    class Column
      ROLE_PRESETS = {
        backlog: {add: true},
        done: {color: :green, collapsed: true}
      }.freeze

      attr_reader :key, :label, :color, :wip, :scope, :on_drop, :accepts, :actions

      def initialize(key, label: nil, color: nil, wip: nil, scope: nil, on_drop: nil,
        collapsed: nil, add: nil, accepts: nil, locked: nil, role: nil)
        preset = role ? ROLE_PRESETS.fetch(role) { raise ArgumentError, "Unknown column role: #{role.inspect}. Valid: #{ROLE_PRESETS.keys.inspect}" } : {}
        @key = key.to_sym
        @label = label || key.to_s.titleize
        @color = color.nil? ? preset[:color] : color
        @wip = wip
        @scope = scope
        @on_drop = on_drop
        @collapsed = collapsed.nil? ? preset[:collapsed] : collapsed
        @add = add.nil? ? preset[:add] : add
        @accepts = accepts.nil? ? true : accepts
        @locked = locked || false
        @actions = []
      end

      def action(key, interaction:, on: :all, label: nil, icon: nil, confirmation: nil)
        @actions << Action.new(key: key.to_sym, interaction:, on:, label:, icon:, confirmation:)
      end

      def collapsed? = !!@collapsed
      def add? = !!@add
      def locked? = @locked

      # Column-level accepts check — used for client-side drop hints and as the
      # first gate in the move handler (before the record is needed).
      # Proc accepts: is treated as permissive at the column level; call
      # accepts_record? with the actual record to evaluate the predicate.
      def accepts?(source_key)
        case @accepts
        when Array then @accepts.include?(source_key)
        when true, false then @accepts
        # Proc/predicate case: permit at the column level here; the move handler
        # evaluates the predicate per-card via accepts_record? with the actual record.
        else true
        end
      end

      # Per-card accepts check — evaluates a Proc accepts: against the actual
      # record.  Called by the move handler after the record is loaded.
      #
      # Convention for Proc accepts:
      #   accepts: ->(card) { … }   # receives the record, returns true/false
      #
      # For non-Proc values the behaviour matches accepts?(source_key) exactly,
      # so the move handler can unconditionally switch to accepts_record?.
      def accepts_record?(record, source_key)
        case @accepts
        when Array then @accepts.include?(source_key)
        when true, false then @accepts
        when Proc then @accepts.call(record)
        else true
        end
      end
    end
  end
end
