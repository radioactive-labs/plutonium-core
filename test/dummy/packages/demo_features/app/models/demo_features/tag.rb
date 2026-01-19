require_relative "../demo_features"

class DemoFeatures::Tag < DemoFeatures::ResourceRecord
  has_many :product_tags, class_name: "DemoFeatures::ProductTag", dependent: :destroy
  has_many :products, through: :product_tags, class_name: "DemoFeatures::Product"

  validates :name, presence: true, uniqueness: true
end
