# frozen_string_literal: true

require_relative "wizard/errors"
require_relative "wizard/configuration"

module Plutonium
  # The Plutonium wizard subsystem: multi-step, DB-backed, data-capture wizards.
  module Wizard
    # The union `data` schema (§2.6) and the runner's inline validator both build
    # anonymous ActiveModel classes from a step's `attribute_schema`. A `using:`
    # import contributes the model's column types (e.g. `:text`), which
    # ActiveModel's type registry doesn't know. Fall back to `:string` for any type
    # the registry can't resolve so the snapshot/validator still builds — the
    # staged value is stored/displayed as-is.
    def self.safe_attribute_type(type)
      ActiveModel::Type.lookup(type)
      type
    rescue ArgumentError
      :string
    end

    # Compute a wizard run's identity digest (§4.1), shared by the runner/driving
    # layer (which creates rows) and the gate (which recomputes the key) so the
    # two are byte-identical — if they diverge, one-time gating silently breaks.
    #
    # A wizard with a `concurrency_key` is hashed over its resolved key value(s)
    # (the tenant is folded in by {Base#concurrency_key_value}); otherwise it's
    # hashed over the per-launch `wizard_token`.
    #
    # The wizard's `concurrency_key` resolver and tenancy fold run in a transient
    # wizard instance seeded with the identity context. A resolver that references
    # a missing context method raises a clear error.
    #
    # @return [String] the hex SHA256 instance_key
    def self.compute_instance_key(wizard_class:, current_user:, current_scoped_entity:, anchor:, wizard_token:)
      unless wizard_class.concurrency_key?
        return InstanceKey.tokened(wizard_class.name, wizard_token)
      end

      probe = wizard_class.new
      probe.current_user = current_user
      probe.current_scoped_entity = current_scoped_entity
      probe.wizard_token = wizard_token
      probe.anchor = anchor if wizard_class.anchored?
      key_value = probe.concurrency_key_value
      InstanceKey.concurrency(wizard_class.name, key_value)
    rescue NameError => e
      raise ArgumentError,
        "#{wizard_class.name}'s concurrency_key referenced a method that isn't " \
        "available in this context (#{e.message}). Available: current_user, " \
        "current_scoped_entity, anchor, wizard_token, or a host method."
    end

    # The "continue where you left off" listing (§4.5): in-progress wizard runs
    # owned by +owner+, optionally narrowed to a tenant +scope+, each enriched with
    # the wizard's label/icon, current step (+ label), updated_at, and a resolved
    # resume_url (nil with a reason when a mount can't be resolved generically).
    #
    #   Plutonium::Wizard.in_progress_for(current_user, scope: current_scoped_entity)
    #
    # @param owner [Object]
    # @param scope [Object, nil]
    # @return [Array<Plutonium::Wizard::Resume::Entry>]
    def self.in_progress_for(owner, scope: nil)
      Resume.entries_for(owner, scope: scope)
    end
  end
end
