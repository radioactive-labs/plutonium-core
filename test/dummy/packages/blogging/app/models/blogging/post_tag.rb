require_relative "../blogging"

class Blogging::PostTag < Blogging::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  # add model configurations above.

  belongs_to :post, class_name: "Blogging::Post"
  belongs_to :tag, class_name: "Blogging::Tag"
  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  scope :associated_with_organization, ->(organization) {
    joins(:post).where(blogging_posts: {organization_id: organization.id})
  }
  # add scopes above.

  validates :post_id, uniqueness: {scope: :tag_id}
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
