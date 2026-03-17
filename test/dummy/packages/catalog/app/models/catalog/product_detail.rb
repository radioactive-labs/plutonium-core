require_relative "../catalog"

class Catalog::ProductDetail < Catalog::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

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

  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
