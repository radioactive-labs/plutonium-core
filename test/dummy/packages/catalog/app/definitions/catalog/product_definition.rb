class Catalog::ProductDefinition < Catalog::ResourceDefinition
  field :description, as: :text
  # `featured` auto-renders: switch in forms, boolean pill in show/index.

  nested_input :variants do |definition|
    definition.input :name
    definition.input :sku
    definition.input :stock_count
  end
  nested_input :product_detail do |definition|
    definition.input :specifications
    definition.input :warranty_info
  end

  search do |scope, query|
    scope.where("name LIKE ? OR description LIKE ?", "%#{query}%", "%#{query}%")
  end

  scope :active
  scope :draft
  scope :discontinued

  filter :name, with: :text, predicate: :contains
  filter :status, with: :select, choices: Catalog::Product.statuses.keys
  filter :category, with: :association, class_name: "Catalog::Category"

  sort :name
  sort :price_cents
  sort :status
  sort :created_at
  default_sort :created_at, :desc

  action :publish, interaction: Catalog::PublishProduct
  action :discontinue, interaction: Catalog::DiscontinueProduct
  action :collect_spec, interaction: Catalog::CollectSpec
end
