require_relative "../demo_features"

class DemoFeatures::Review < DemoFeatures::ResourceRecord
  belongs_to :product, class_name: "DemoFeatures::Product"
  belongs_to :user, optional: true

  scope :verified, -> { where(verified: true) }
  scope :approved, -> { where.not(approved_at: nil) }
  scope :pending, -> { where(approved_at: nil) }

  validates :body, presence: true
  validates :rating, presence: true, numericality: {in: 1..5}
  validates :user_id, uniqueness: {scope: :product_id}, allow_nil: true
end
