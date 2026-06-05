# frozen_string_literal: true

require "delegate"

module Plutonium
  module Action
    # Evaluation scope for an action's `condition:` proc.
    #
    # Exposes the contextual record as both `object` and `record`, and delegates
    # everything else to the request's **view context** — the object render
    # components forward their helpers to — so a condition can use current_user,
    # params, request, allowed_to?, resource_record!, etc. directly, exactly
    # like the `condition:` procs on inputs/displays/columns.
    #
    # Delegating to the view context (not a render component) matters: the
    # component exposes params/request only as PRIVATE methods, which a delegator
    # can't forward; the view context exposes them publicly.
    #
    # `record`/`object` is the row/shown record for record and
    # collection-record actions, and nil for resource/bulk actions (no single
    # record in scope) — so guard with `object&.…` in conditions shared across
    # action kinds.
    class ConditionContext < SimpleDelegator
      attr_reader :record
      alias_method :object, :record

      def initialize(view_context, record)
        super(view_context)
        @record = record
      end
    end
  end
end
