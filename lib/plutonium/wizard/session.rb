# frozen_string_literal: true

module Plutonium
  module Wizard
    # ActiveRecord model backing the +plutonium_wizard_sessions+ table.
    #
    # Identity is the derived {InstanceKey} digest stored in +instance_key+; the
    # polymorphic owner/anchor/scope refs exist for listing and rebuilding context,
    # not for identity. Encryption (+encrypt_data+) is applied by the wizard class
    # when requested, not statically here.
    class Session < ActiveRecord::Base
      self.table_name = "plutonium_wizard_sessions"

      belongs_to :owner, polymorphic: true, optional: true
      belongs_to :anchor, polymorphic: true, optional: true
      belongs_to :scope, polymorphic: true, optional: true

      enum :status,
        {in_progress: "in_progress", completing: "completing", completed: "completed"},
        prefix: true

      # Idle rows eligible for the abandonment sweep: still running (in_progress or
      # mid-finalize completing), with a concrete expiry that has passed. Rows with
      # a null +expires_at+ (cleanup_after :never) are never swept.
      scope :sweepable, ->(now) {
        where(status: %w[in_progress completing])
          .where.not(expires_at: nil)
          .where(expires_at: ..now)
      }
    end
  end
end
