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
  field :color, as: :string
  input :color, as: :color  # Color picker input

  # Columns
  column :name
  column :color do |tag|
    tag.color
  end
  column :products_count do |tag|
    tag.products.count
  end
end
