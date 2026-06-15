# frozen_string_literal: true

# A minimal one-time onboarding wizard (§9) for the gate integration test. Keyed
# per-user: once a user completes it, the durable `completed` session row marks
# them done forever, so `ensure_wizard_completed` lets them through afterward.
#
# A single trivial step + review keeps the flow short; `execute` returns success
# (no record needed — the completion marker itself is the durable signal).
class WelcomeWizard < Plutonium::Wizard::Base
  presents label: "Welcome"

  one_time once_per: :user

  step :greeting do
    attribute :acknowledged, :string
    input :acknowledged
    validates :acknowledged, presence: true
  end

  review label: "Review"

  def execute
    succeed.with_message("Welcome aboard!")
  end
end
