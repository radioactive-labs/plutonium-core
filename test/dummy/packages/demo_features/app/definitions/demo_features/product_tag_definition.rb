class DemoFeatures::ProductTagDefinition < DemoFeatures::ResourceDefinition
  # Sorting
  sorts :position, :created_at
  default_sort :position, :asc

  # Filters
  filter :product, with: :association, class_name: DemoFeatures::Product
  filter :tag, with: :association, class_name: DemoFeatures::Tag

  # Fields
  field :product, as: :association
  field :tag, as: :association
  field :position, as: :integer

  # Columns
  column :product
  column :tag
  column :position
end
