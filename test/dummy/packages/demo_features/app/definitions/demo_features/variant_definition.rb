class DemoFeatures::VariantDefinition < DemoFeatures::ResourceDefinition
  # Search
  search do |scope, query|
    scope.where("name LIKE :q OR sku LIKE :q", q: "%#{query}%")
  end

  # Scopes
  scope :in_stock

  # Filters
  filter :name, with: :text, predicate: :contains
  filter :active, with: :boolean
  filter :product, with: :association, class_name: DemoFeatures::Product

  # Sorting
  sorts :name, :sku, :price, :stock_count
  default_sort :name, :asc

  # Fields
  field :product, as: :association
  field :name, as: :string
  field :sku, as: :string
  field :price, as: :decimal
  field :stock_count, as: :integer
  field :active, as: :boolean
  input :active, as: :checkbox
  field :options, as: :json
  input :options, as: :key_value

  # Columns
  column :product
  column :name
  column :sku
  column :price do |variant|
    variant.price ? "$#{"%.2f" % variant.price}" : "-"
  end
  column :stock_count
  column :active
end
