class Comment < ::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  # add model configurations above.

  belongs_to :commentable, polymorphic: true
  belongs_to :user
  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  scope :associated_with_organization, ->(organization) {
    joins(
      "LEFT JOIN blogging_posts ON comments.commentable_type IN ('Blogging::Post', 'Blogging::Article', 'Blogging::Tutorial') AND comments.commentable_id = blogging_posts.id " \
      "LEFT JOIN catalog_products ON comments.commentable_type = 'Catalog::Product' AND comments.commentable_id = catalog_products.id"
    ).where("blogging_posts.organization_id = :org_id OR catalog_products.organization_id = :org_id", org_id: organization.id)
  }
  # add scopes above.

  validates :body, presence: true
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
