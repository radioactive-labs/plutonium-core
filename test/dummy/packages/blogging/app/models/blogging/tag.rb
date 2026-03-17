require_relative "../blogging"

class Blogging::Tag < Blogging::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  # add model configurations above.

  # add belongs_to associations above.

  # add has_one associations above.

  has_many :post_tags, class_name: "Blogging::PostTag", foreign_key: :tag_id, dependent: :destroy
  has_many :posts, through: :post_tags, class_name: "Blogging::Post"
  # add has_many associations above.

  # add attachments above.

  scope :associated_with_organization, ->(organization) {
    joins(post_tags: :post).where(blogging_posts: {organization_id: organization.id}).distinct
  }
  # add scopes above.

  validates :name, presence: true, uniqueness: true
  validates :color, presence: true
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
