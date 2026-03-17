require_relative "../catalog"

class Catalog::Product < Catalog::ResourceRecord
  # add concerns above.

  # add constants above.

  enum :status, {draft: 0, active: 1, discontinued: 2}, default: :draft
  # add enums above.

  has_cents :price_cents
  # add model configurations above.

  belongs_to :category, class_name: "Catalog::Category"
  belongs_to :user
  belongs_to :organization
  # add belongs_to associations above.

  has_one :product_detail, class_name: "Catalog::ProductDetail", foreign_key: :product_id, inverse_of: :product, dependent: :destroy
  has_one :product_metadata, class_name: "Catalog::ProductMetadata", foreign_key: :product_id, inverse_of: :product, dependent: :destroy
  # add has_one associations above.

  has_many :variants, class_name: "Catalog::Variant", foreign_key: :product_id, inverse_of: :product, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :reviews, class_name: "Catalog::Review", foreign_key: :product_id, dependent: :destroy
  # add has_many associations above.

  # add attachments above.

  accepts_nested_attributes_for :product_detail, allow_destroy: true
  accepts_nested_attributes_for :variants, allow_destroy: true

  scope :active, -> { where(status: :active) }
  scope :draft, -> { where(status: :draft) }
  scope :discontinued, -> { where(status: :discontinued) }
  scope :in_stock, -> { joins(:variants).where("catalog_variants.stock_count > 0").distinct }
  # add scopes above.

  validates :name, presence: true
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
