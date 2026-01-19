require_relative "../demo_features"

class DemoFeatures::ProductTag < DemoFeatures::ResourceRecord
  belongs_to :product, class_name: "DemoFeatures::Product"
  belongs_to :tag, class_name: "DemoFeatures::Tag"

  validates :product_id, uniqueness: {scope: :tag_id}

  default_scope { order(:position) }
end
