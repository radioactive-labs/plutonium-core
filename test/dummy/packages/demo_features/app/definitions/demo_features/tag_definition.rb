class DemoFeatures::TagDefinition < DemoFeatures::ResourceDefinition
  # Search
  search do |scope, query|
    scope.where("name LIKE ?", "%#{query}%")
  end

  # Sorting
  sorts :name, :created_at
  default_sort :name, :asc

  # Filters
  filter :name, with: :text, predicate: :contains

  # Fields
  field :name, as: :string
  field :color, as: :color

  # Columns
  column :name
  column :products_count do |tag|
    tag.products.count
  end
end
