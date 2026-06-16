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

        def completed?(wizard:, owner: Base::OMITTED, anchor: Base::OMITTED)
          # An explicitly-passed nil key can never match a row; only an OMITTED key
          # drops the predicate (matching the AR store's behavior).
          return false if owner.nil? || anchor.nil?

          @rows.values.any? do |s|
            s.status == "completed" &&
              s.wizard == wizard.to_s &&
              (owner.equal?(Base::OMITTED) || s.owner == owner) &&
              (anchor.equal?(Base::OMITTED) || s.anchor == anchor)
          end
        end

        def in_progress_for(owner)
          @rows.values.select { |s| s.status == "in_progress" && s.owner == owner }
        end
      end
    end
  end
end
