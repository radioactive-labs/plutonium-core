# frozen_string_literal: true

# An ActiveStorage-backed model for the wizard-attachment demo. Plain
# `has_one_attached` resolves to ActiveStorage (the dummy keeps the AS railtie).
class AsDoc < ApplicationRecord
  has_one_attached :file
end
