# frozen_string_literal: true

module Plutonium
  module Wizard
    module Store
      # In-memory store for fast, DB-free unit tests (and a template for future
      # adapters). Mirrors {ActiveRecord}'s observable behavior.
      class Memory < Base
        def initialize
          @rows = {}
        end

        def read(instance_key)
          @rows[instance_key]&.dup
        end

        def write(instance_key, state, cleanup_after:)
          state = state.dup
          state.instance_key = instance_key
          state.status ||= "in_progress"
          @rows[instance_key] = state
        end

        def complete(instance_key)
          state = @rows.fetch(instance_key)
          state.status = "completed"
          state.data = {}
          state.persisted = {}
          state.visited = []
          state
        end

        def clear(instance_key)
          @rows.delete(instance_key)
        end

        def completed?(instance_key:)
          row = @rows[instance_key]
          !!row && row.status == "completed"
        end
      end
    end
  end
end
