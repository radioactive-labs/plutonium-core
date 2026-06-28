# frozen_string_literal: true

# A branching wizard used to prove the driving layer refuses a POST to an
# unreachable (branch-hidden) step. Step `choice` selects a branch; `secret` is
# only visible when mode == "yes". Its `on_submit` records an UNCOMPENSATED side
# effect into a class-level sink (not a `persist`ed record), so a test can detect
# whether it ran at all — the engine's branch-prune would destroy any persisted
# record, masking the symptom, but it cannot un-fire a raw side effect.
class BranchGuardWizard < Plutonium::Wizard::Base
  @fired = []
  class << self
    attr_reader :fired
  end

  step :choice do
    attribute :mode, :string
    validates :mode, presence: true
  end

  step :secret, condition: -> { data.choice.mode == "yes" } do
    attribute :note, :string
    on_submit { BranchGuardWizard.fired << "secret" }
  end

  review label: "Review"

  def execute = succeed(:done)
end
