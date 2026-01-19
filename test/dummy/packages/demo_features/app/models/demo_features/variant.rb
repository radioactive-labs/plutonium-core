require_relative "../demo_features"

class DemoFeatures::Variant < DemoFeatures::ResourceRecord
  belongs_to :product, class_name: "DemoFeatures::Product"

  scope :in_stock, -> { where("stock_count > 0") }

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :price, numericality: {greater_than_or_equal_to: 0}, allow_nil: true
  validates :stock_count, numericality: {greater_than_or_equal_to: 0}
end
