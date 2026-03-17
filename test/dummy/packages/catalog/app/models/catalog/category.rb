require_relative "../catalog"

class Catalog::Category < Catalog::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  # add model configurations above.

  belongs_to :parent, class_name: "Catalog::Category", optional: true, inverse_of: :subcategories
  # add belongs_to associations above.

  has_one :morph_demo, class_name: "Catalog::MorphDemo", foreign_key: :category_id, dependent: :destroy
  # add has_one associations above.

  has_many :subcategories, class_name: "Catalog::Category", foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify
  has_many :products, class_name: "Catalog::Product", dependent: :restrict_with_error
  # add has_many associations above.

  # add attachments above.

  scope :associated_with_organization, ->(organization) {
    joins(:products).where(catalog_products: {organization_id: organization.id}).distinct
  }
  # add scopes above.

  validates :name, presence: true
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
