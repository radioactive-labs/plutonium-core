class DemoFeatures::CategoryDefinition < DemoFeatures::ResourceDefinition
  # Search
  search do |scope, query|
    scope.where("name LIKE :q OR description LIKE :q", q: "%#{query}%")
  end

  # Sorting
  sorts :name, :created_at
  default_sort :name, :asc

  # Filters
  filter :name, with: :text, predicate: :contains

  # Fields
  field :name, as: :string
  field :description, as: :text
  input :description, as: :markdown

  # Columns
  column :name
  column :description do |category|
    category.description&.truncate(50)
  end
  column :products_count do |category|
    category.products.count
  end

  # Nested resources
  nested_input :products,
    using: DemoFeatures::ProductDefinition,
    fields: [:name, :sku, :price, :status]

  # Actions
  action :bulk_set_description, interaction: DemoFeatures::BulkSetCategoryDescription
end
