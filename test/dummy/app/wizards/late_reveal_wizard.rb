# frozen_string_literal: true

# Every step AFTER the first is revealed BY the first step's answer, so before
# `details` is submitted `details` is the ONLY visible step. Used to prove the
# driving layer decides advance-vs-finalize AFTER staging the submission:
# deciding first read `details` as the last visible step, finalized, found
# `details` unsubmitted and bounced back to it — forever, with `setup`
# unreachable and no run ever written.
#
# Picking `basic` hides everything after `details`, so that POST legitimately
# ends the flow (a conditional `review` that branches out is still terminal).
class LateRevealWizard < Plutonium::Wizard::Base
  presents label: "Late reveal"

  # A bare relaunch always mints a fresh run — this flow is started clean.
  on_relaunch :new

  step :details do
    attribute :template, :string
    input :template, as: :select, choices: %w[pro basic]
    validates :template, presence: true
  end

  step :setup, condition: -> { data.details.template == "pro" } do
    attribute :note, :string
    input :note
  end

  review label: "Review", condition: -> { data.details.template == "pro" }

  def execute = succeed.with_message("Done")

  # Portal-level wizard with no resource policy — gate it to authenticated users.
  def authorize? = current_user.present?
end
