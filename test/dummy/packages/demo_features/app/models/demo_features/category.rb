require_relative "../demo_features"

class DemoFeatures::Category < DemoFeatures::ResourceRecord
  has_many :products, class_name: "DemoFeatures::Product", dependent: :nullify

  validates :name, presence: true
end
