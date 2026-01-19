require_relative "../demo_features"

class DemoFeatures::Product < DemoFeatures::ResourceRecord
  # Enum for status field
  enum :status, {draft: 0, active: 1, archived: 2}, default: :draft

  belongs_to :category, class_name: "DemoFeatures::Category", optional: true

  has_many :product_tags, class_name: "DemoFeatures::ProductTag", dependent: :destroy
  has_many :tags, through: :product_tags, class_name: "DemoFeatures::Tag"
  has_many :variants, class_name: "DemoFeatures::Variant", dependent: :destroy
  has_many :reviews, class_name: "DemoFeatures::Review", dependent: :destroy

  scope :published, -> { where.not(published_at: nil) }
  scope :in_stock, -> { where("stock_count > 0") }
  scope :featured, -> { where(featured: true) }

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :price, numericality: {greater_than_or_equal_to: 0}, allow_nil: true
  validates :stock_count, numericality: {greater_than_or_equal_to: 0}

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
