# frozen_string_literal: true

module Plutonium
  module Wizard
    module Store
      # Storage port for wizard sessions. Adapters exchange {State} value objects
      # and are keyed by the derived {InstanceKey} digest.
      class Base
        # @param instance_key [String]
        # @return [State, nil]
        def read(instance_key) = raise NotImplementedError

        # Upsert by +instance_key+. Stamps +expires_at = now + cleanup_after+
        # (nil cleanup_after → null expiry).
        #
        # @param instance_key [String]
        # @param state [State]
        # @param cleanup_after [ActiveSupport::Duration, nil]
        # @return [State]
        def write(instance_key, state, cleanup_after:) = raise NotImplementedError

        # Mark completed: status "completed", stamp completed_at, null data/persisted.
        #
        # @param instance_key [String]
        def complete(instance_key) = raise NotImplementedError

        # Delete the row.
        #
        # @param instance_key [String]
        def clear(instance_key) = raise NotImplementedError

        # One-time completion check.
        #
        # @return [Boolean]
        def completed?(wizard:, owner: nil, anchor: nil) = raise NotImplementedError

        # In-progress sessions owned by +owner+.
        #
        # @return [Array<State>]
        def in_progress_for(owner) = raise NotImplementedError
      end
    end
  end
end
