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

      attr_reader :key, :label, :color, :wip, :scope, :on_enter, :on_exit, :accepts, :actions, :enter_interaction

      def initialize(key, label: nil, color: nil, wip: nil, scope: nil, on_enter: nil, on_exit: nil, on_drop: nil,
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
        # accepts: is purely structural (topology + client drop hints): true/false
        # or an Array of source keys. The Proc form was removed — record/user
        # conditions belong in the kanban_move? policy, which sees the record and
        # the from/to columns. Fail loud rather than silently treating a stale Proc
        # as permissive (which would OPEN UP a column that used to restrict drops).
        if accepts.is_a?(Proc)
          raise ArgumentError, "kanban column `accepts:` no longer accepts a Proc; use true/false or an Array of source keys, and put record/user conditions in the kanban_move? policy."
        end
        @key = key.to_sym
        @label = label || key.to_s.titleize
        @color = color.nil? ? preset[:color] : color
        @wip = wip
        @scope = scope
        @on_enter = on_enter
        @on_exit = on_exit
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

      # Internal action-registration key for the enter interaction, scoped to the
      # column: :blocked → :blocked_enter_interaction. Nil when unset.
      #
      # Column-scoped (not class-name-derived) so it is unique by construction — a
      # column has at most one enter_interaction, so two columns can never collide
      # even if they reuse the same interaction class. This key is ONLY an internal
      # form/param routing handle; it is NOT an authorization name. The move (and
      # therefore the interaction) is authorized solely by kanban_move? — the
      # interaction has no policy method of its own.
      def enter_interaction_key
        return nil unless @enter_interaction
        :"#{key}_enter_interaction"
      end

      def action(key, interaction:, on: :all, label: nil, icon: nil, confirmation: nil)
        @actions << Action.new(key: key.to_sym, interaction:, on:, label:, icon:, confirmation:)
      end

      def collapsed? = !!@collapsed
      def add? = !!@add
      def locked? = @locked

      # Whether a card from `source_key` may be dropped into this column. Purely
      # structural — @accepts is normalized to true/false or an Array of source
      # keys (the constructor rejects a Proc). Drives both the server-side gate in
      # the move handler and the client-side drop hint (data-kanban-accepts).
      def accepts?(source_key)
        case @accepts
        when Array then @accepts.include?(source_key)
        else @accepts # true or false
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
