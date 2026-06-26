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
        preset = role ? ROLE_PRESETS.fetch(role, {}) : {}
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

      def accepts?(source_key)
        case @accepts
        when Array then @accepts.include?(source_key)
        when true, false then @accepts
        else true
        end
      end
    end
  end
end
