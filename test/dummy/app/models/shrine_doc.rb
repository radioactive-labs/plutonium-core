# frozen_string_literal: true

# An active_shrine-backed model for the wizard-attachment demo. Including
# `ActiveShrine::Model` makes THIS model's `has_one_attached` resolve to
# active_shrine (Shrine) instead of ActiveStorage — per-model, so the two backends
# coexist in the dummy.
class ShrineDoc < ApplicationRecord
  include ActiveShrine::Model

  has_one_attached :file
end
