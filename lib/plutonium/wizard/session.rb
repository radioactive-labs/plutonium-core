# frozen_string_literal: true

module Plutonium
  module Wizard
    # ActiveRecord model backing the +plutonium_wizard_sessions+ table.
    #
    # Identity is the derived {InstanceKey} digest stored in +instance_key+; the
    # polymorphic owner/anchor/scope refs exist for listing and rebuilding context,
    # not for identity. At-rest encryption (the wizard's +encrypt_data+ opt-in) is
    # applied by {Store::ActiveRecord} as a self-describing envelope in the +data+
    # column, not statically here — so this model stays a plain schema mapping.
    class Session < ActiveRecord::Base
      self.table_name = "plutonium_wizard_sessions"

      belongs_to :owner, polymorphic: true, optional: true
      belongs_to :anchor, polymorphic: true, optional: true
      belongs_to :scope, polymorphic: true, optional: true

      enum :status,
        {in_progress: "in_progress", completing: "completing", completed: "completed"},
        prefix: true

      # How long a row may sit in +completing+ before the sweep treats it as a
      # CRASHED finalize and reaps it. A healthy finalize flips to +completing+,
      # runs +execute+, and completes/clears the row within seconds — but +execute+
      # runs OUTSIDE the completion lock and does not bump +expires_at+, so a sweep
      # firing mid-finalize must NOT cancel it (that would destroy the run's
      # tracked records out from under the in-flight +execute+, §6.2). The grace
      # window distinguishes a finalize that is still running (recent +updated_at+)
      # from one that crashed (stale +updated_at+). Generous on purpose.
      COMPLETING_GRACE = 15.minutes

      # Idle rows eligible for the abandonment sweep, by status:
      #
      # - +in_progress+ — abandoned: a concrete +expires_at+ (cleanup_after) that
      #   has passed. Rows with a null +expires_at+ (cleanup_after :never) are never
      #   swept.
      # - +completing+ — a finalize that CRASHED mid-flight: it has been
      #   +completing+ longer than {COMPLETING_GRACE} (its +updated_at+, stamped
      #   when it entered +completing+, is older than now - grace). This keeps the
      #   sweep from racing an +execute+ that is still running (§6.2).
      #
      # +completed+ rows are never swept.
      scope :sweepable, ->(now, completing_grace: COMPLETING_GRACE) {
        in_progress =
          status_in_progress.where.not(expires_at: nil).where(expires_at: ..now)
        crashed_completing =
          status_completing.where(updated_at: ..(now - completing_grace))
        in_progress.or(crashed_completing)
      }
    end
  end
end
