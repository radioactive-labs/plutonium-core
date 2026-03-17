require_relative "../catalog"

class Catalog::Review < Catalog::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  # add model configurations above.

  belongs_to :product, class_name: "Catalog::Product"
  belongs_to :user
  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  scope :associated_with_organization, ->(organization) {
    joins(:product).where(catalog_products: {organization_id: organization.id})
  }
  scope :verified, -> { where(verified: true) }
  scope :pending_verification, -> { where(verified: false) }
  # add scopes above.

  validates :title, presence: true
  validates :body, presence: true
  validates :rating, presence: true, numericality: {in: 1..5, only_integer: true}
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
