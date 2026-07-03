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

      attr_reader :key, :label, :color, :wip, :scope, :on_enter, :accepts, :actions, :enter_interaction

      def initialize(key, label: nil, color: nil, wip: nil, scope: nil, on_enter: nil, on_drop: nil,
        collapsed: nil, add: nil, accepts: nil, locked: nil, role: nil, enter_interaction: nil, drop_interaction: nil)
        # on_drop:/drop_interaction: were renamed to on_enter:/enter_interaction:.
        # Resolve the deprecated aliases first (dev/test raise; deployed envs warn
        # and map — see resolve_renamed_option) so the rest of initialize only
        # ever sees the new names.
        on_enter = resolve_renamed_option(:on_drop, on_drop, :on_enter, on_enter)
        enter_interaction = resolve_renamed_option(:drop_interaction, drop_interaction, :enter_interaction, enter_interaction)

        preset = role ? ROLE_PRESETS.fetch(role) { raise ArgumentError, "Unknown column role: #{role.inspect}. Valid: #{ROLE_PRESETS.keys.inspect}" } : {}
        if enter_interaction && !(enter_interaction.is_a?(Class) && enter_interaction < Plutonium::Resource::Interaction)
          raise ArgumentError, "enter_interaction: must be a Plutonium::Resource::Interaction subclass, got #{enter_interaction.inspect}"
        end
        @key = key.to_sym
        @label = label || key.to_s.titleize
        @color = color.nil? ? preset[:color] : color
        @wip = wip
        @scope = scope
        @on_enter = on_enter
        @collapsed = collapsed.nil? ? preset[:collapsed] : collapsed
        @add = add.nil? ? preset[:add] : add
        @accepts = accepts.nil? || accepts
        @locked = locked || false
        @enter_interaction = enter_interaction
        @actions = []
      end

      # A column may run an input-collecting Interaction when a card ENTERS it
      # (e.g. "mark lead as lost with a reason"). When set, the drop opens the
      # interaction's form as a modal before the move is committed.
      def enter_interaction? = !!@enter_interaction

      # The conventional record-action key for the enter interaction, derived
      # from its class name: MarkLostInteraction → :mark_lost. Nil when unset.
      def enter_interaction_key
        return nil unless @enter_interaction
        @enter_interaction.name.demodulize.sub(/Interaction\z/, "").underscore.to_sym
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

      private

      # Bridge a renamed column option. `on_drop:`/`drop_interaction:` became
      # `on_enter:`/`enter_interaction:`. To avoid breaking live deployments on
      # upgrade we DON'T hard-fail in deployed envs — we log a deprecation and map
      # the old value onto the new name. But local envs (development/test) raise,
      # so the rename is caught during development and can't silently ship. If
      # both the old and new names are given, the new one wins.
      def resolve_renamed_option(old_name, old_value, new_name, new_value)
        return new_value if old_value.nil?

        if Rails.env.local?
          raise ArgumentError,
            "kanban column `#{old_name}:` has been renamed to `#{new_name}:` — update your definition."
        end

        Rails.logger.warn { "[plutonium] kanban column `#{old_name}:` is deprecated; rename it to `#{new_name}:`." }
        new_value.nil? ? old_value : new_value
      end
    end
  end
end
