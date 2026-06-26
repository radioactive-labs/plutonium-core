# frozen_string_literal: true

module Plutonium
  module Kanban
    # Builds ActionCable stream names and broadcasts Turbo Stream updates for
    # opt-in realtime kanban boards.
    #
    # ## Tenant isolation
    #
    # The stream name is a three-segment string:
    #
    #   "kanban:<tenant>:<resource>"
    #
    # where <tenant> is the scoped entity's GID param (e.g. "Z2lkOi8vYXBwL09yZy8x")
    # or the literal string "global" for unscoped portals.
    #
    # Two viewers are on the SAME stream only when they share identical
    # resource_class AND scoped_entity — different tenants can never share a
    # stream because their GID params are distinct by definition.
    module Broadcaster
      extend self

      # Returns the streamables array that identifies this board's ActionCable stream.
      #
      # Pass the returned array directly to turbo-rails helpers:
      #
      #   turbo_stream_from(*Broadcaster.stream_name(resource_class: Task, scoped_entity: org))
      #   Turbo::StreamsChannel.broadcast_stream_to(*stream_name, content:)
      #
      # @param resource_class [Class] the ActiveRecord model class for the board
      # @param scoped_entity [ActiveRecord::Base, nil] the tenant record, or nil
      #   for portals that are not entity-scoped
      # @return [Array<String>]
      def stream_name(resource_class:, scoped_entity:)
        entity_segment = scoped_entity&.to_gid_param || "global"
        ["kanban", entity_segment, resource_class.name]
      end

      # Broadcasts the Turbo Stream HTML to all ActionCable subscribers watching
      # this board's stream.
      #
      # @param resource_class [Class]
      # @param scoped_entity [ActiveRecord::Base, nil]
      # @param content [String] the raw turbo-stream HTML (one or more
      #   <turbo-stream> tags) to push to subscribers
      def broadcast(resource_class:, scoped_entity:, content:)
        Turbo::StreamsChannel.broadcast_stream_to(
          *stream_name(resource_class:, scoped_entity:),
          content: content
        )
      end
    end
  end
end
