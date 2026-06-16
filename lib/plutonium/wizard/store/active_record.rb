# frozen_string_literal: true

module Plutonium
  module Wizard
    module Store
      # Shipped store, backed by the +plutonium_wizard_sessions+ table via {Session}.
      class ActiveRecord < Base
        def read(instance_key)
          row = Session.find_by(instance_key: instance_key)
          row && to_state(row)
        end

        def write(instance_key, state, cleanup_after:)
          row = Session.find_or_initialize_by(instance_key: instance_key)
          row.wizard = state.wizard
          row.current_step = state.current_step
          row.status ||= "in_progress"
          row.data = state.data
          row.tracked_records = state.persisted
          row.visited = state.visited
          row.owner = state.owner
          row.anchor = state.anchor
          row.scope = state.scope
          row.token = state.token
          row.expires_at = cleanup_after ? Time.current + cleanup_after : nil
          row.save!
          to_state(row)
        end

        def complete(instance_key)
          row = Session.find_by!(instance_key: instance_key)
          row.update!(status: "completed", completed_at: Time.current, data: {}, tracked_records: {}, visited: [])
        end

        def clear(instance_key)
          Session.where(instance_key: instance_key).delete_all
        end

        def completed?(instance_key:)
          Session.status_completed.where(instance_key: instance_key).exists?
        end

        def in_progress_for(owner, scope: nil)
          rel = Session.status_in_progress.where(owner: owner)
          rel = rel.where(scope: scope) unless scope.nil?
          rel.order(updated_at: :desc).map { |row| to_state(row) }
        end

        private

        def to_state(row)
          State.new(
            wizard: row.wizard,
            instance_key: row.instance_key,
            current_step: row.current_step,
            status: row.status,
            data: row.data,
            persisted: row.tracked_records,
            visited: row.visited,
            owner: row.owner,
            anchor: row.anchor,
            scope: row.scope,
            token: row.token
          )
        end
      end
    end
  end
end
