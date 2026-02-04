class DemoFeatures::ProductDefinition < DemoFeatures::ResourceDefinition
  # ===========================================
  # Page Configuration
  # ===========================================
  index_page_title "Products"
  index_page_description "Kitchen sink demo with all field types and features"

  # ===========================================
  # Search
  # ===========================================
  search do |scope, query|
    scope.where("name LIKE :q OR sku LIKE :q OR description LIKE :q", q: "%#{query}%")
  end

  # ===========================================
  # Scopes
  # ===========================================
  scope :published
  scope :in_stock
  scope :featured

  default_scope :published

  # ===========================================
  # Filters - demonstrating all filter types
  # ===========================================

  # Text filters with different predicates
  filter :name, with: :text, predicate: :contains
  filter :sku, with: :text, predicate: :eq

  # Boolean filter
  filter :active, with: :boolean
  filter :featured, with: :boolean

  # Select filter with static choices
  filter :status, with: :select, choices: DemoFeatures::Product.statuses.keys

  # Date filters
  filter :release_date, with: :date, predicate: :gteq
  filter :created_at, with: :date_range

  # Association filter with scoping
  filter :category, with: :association, class_name: DemoFeatures::Category

  # ===========================================
  # Sorting
  # ===========================================
  sorts :name, :sku, :price, :stock_count, :created_at, :updated_at
  sort :category, using: :category_id

  default_sort :created_at, :desc

  # ===========================================
  # Field Customizations - Input Types
  # ===========================================

  # String inputs
  field :name, as: :string
  field :sku, as: :string
  field :slug, as: :string

  # Text inputs
  field :description, as: :text
  input :description, as: :easymde  # Markdown editor
  field :notes, as: :text

  # Numeric inputs
  field :stock_count, as: :integer
  field :weight, as: :float
  field :price, as: :decimal
  field :compare_at_price, as: :decimal

  # Boolean inputs
  field :active, as: :boolean
  input :active, as: :checkbox
  field :featured, as: :boolean
  input :featured, as: :checkbox
  field :taxable, as: :boolean
  input :taxable, as: :checkbox

  # Date/Time inputs
  field :release_date, as: :date
  field :discontinue_date, as: :date
  field :last_restocked_at, as: :datetime
  field :published_at, as: :datetime
  field :available_from_time, as: :time
  field :available_until_time, as: :time

  # JSON inputs
  field :metadata, as: :json
  input :metadata, as: :key_value
  field :specifications, as: :json
  input :specifications, as: :key_value

  # Enum/Select inputs
  field :status, as: :string
  input :status, as: :select, collection: DemoFeatures::Product.statuses.keys

  # Association inputs
  field :category, as: :association

  # ===========================================
  # Column Customizations
  # ===========================================
  column :name
  column :sku
  column :status
  column :price do |product|
    product.price ? "$#{"%.2f" % product.price}" : "-"
  end
  column :stock_count
  column :active
  column :category, label: "Category"

  # ===========================================
  # Conditional Fields (show/hide based on value)
  # ===========================================
  input :compare_at_price, condition: -> { object.featured? }
  input :discontinue_date, condition: -> { object.status == "archived" }

  # ===========================================
  # Nested Inputs
  # ===========================================
  nested_input :variants,
    using: DemoFeatures::VariantDefinition,
    fields: [:name, :sku, :price, :stock_count, :active]

  nested_input :product_tags,
    using: DemoFeatures::ProductTagDefinition,
    fields: [:tag, :position]
end
