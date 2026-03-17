require_relative "../catalog"

class Catalog::Variant < Catalog::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  has_cents :price_cents
  # add model configurations above.

  belongs_to :product, class_name: "Catalog::Product"
  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  scope :associated_with_organization, ->(organization) {
    joins(:product).where(catalog_products: {organization_id: organization.id})
  }
  # add scopes above.

  validates :name, presence: true
  validates :sku, presence: true
  validates :stock_count, presence: true, numericality: {greater_than_or_equal_to: 0}
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
