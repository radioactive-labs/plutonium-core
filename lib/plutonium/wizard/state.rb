# frozen_string_literal: true

module Plutonium
  module Wizard
    # In-memory snapshot of one wizard instance's stored state, exchanged between
    # the {Store} and the runner. Independent of any persistence backend.
    #
    # +data+ and +persisted+ default to an empty hash, +visited+ to an empty
    # array, so callers never have to nil-check them.
    State = Struct.new(
      :wizard,
      :instance_key,
      :current_step,
      :status,
      :data,
      :persisted,
      :visited,
      :owner,
      :anchor,
      :scope,
      :token
    ) do
      def data = self[:data] || {}

      def persisted = self[:persisted] || {}

      def visited = self[:visited] || []
    end
  end
end
