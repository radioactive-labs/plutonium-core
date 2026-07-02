# frozen_string_literal: true

module Plutonium
  module Kanban
    class Column
      ROLE_PRESETS = {
        backlog: {add: true},
        # Terminal columns: collapsed by default, colour signals the outcome.
        # :done is the positive close (green); :lost is the negative close
        # (red) — the natural pair for won/lost pipelines (leads, deals, tickets).
        done: {color: :green, collapsed: true},
        lost: {color: :red, collapsed: true}
      }.freeze

      attr_reader :key, :label, :color, :wip, :scope, :on_drop, :accepts, :actions, :drop_interaction

      def initialize(key, label: nil, color: nil, wip: nil, scope: nil, on_drop: nil,
        collapsed: nil, add: nil, accepts: nil, locked: nil, role: nil, drop_interaction: nil)
        preset = role ? ROLE_PRESETS.fetch(role) { raise ArgumentError, "Unknown column role: #{role.inspect}. Valid: #{ROLE_PRESETS.keys.inspect}" } : {}
        if drop_interaction && !(drop_interaction.is_a?(Class) && drop_interaction < Plutonium::Resource::Interaction)
          raise ArgumentError, "drop_interaction: must be a Plutonium::Resource::Interaction subclass, got #{drop_interaction.inspect}"
        end
        @key = key.to_sym
        @label = label || key.to_s.titleize
        @color = color.nil? ? preset[:color] : color
        @wip = wip
        @scope = scope
        @on_drop = on_drop
        @collapsed = collapsed.nil? ? preset[:collapsed] : collapsed
        @add = add.nil? ? preset[:add] : add
        @accepts = accepts.nil? || accepts
        @locked = locked || false
        @drop_interaction = drop_interaction
        @actions = []
      end

      # A column may run an input-collecting Interaction when a card is dropped
      # into it (e.g. "mark lead as lost with a reason"). When set, the drop
      # opens the interaction's form as a modal before the move is committed.
      def drop_interaction? = !!@drop_interaction

      # The conventional record-action key for the drop interaction, derived
      # from its class name: MarkLostInteraction → :mark_lost. Nil when unset.
      def drop_interaction_key
        return nil unless @drop_interaction
        @drop_interaction.name.demodulize.sub(/Interaction\z/, "").underscore.to_sym
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
