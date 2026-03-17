require_relative "../blogging"

class Blogging::Post < Blogging::ResourceRecord
  # add concerns above.

  # add constants above.

  enum :status, {draft: 0, published: 1, archived: 2}, default: :draft
  # add enums above.

  # add model configurations above.

  belongs_to :user
  belongs_to :author, class_name: "User", optional: true, inverse_of: :authored_posts
  belongs_to :editor, class_name: "User", optional: true, inverse_of: :edited_posts
  belongs_to :organization
  # add belongs_to associations above.

  has_one :post_detail, class_name: "Blogging::PostDetail", foreign_key: :post_id, dependent: :destroy
  # add has_one associations above.

  has_many :comments, as: :commentable, dependent: :destroy
  has_many :post_tags, class_name: "Blogging::PostTag", foreign_key: :post_id, dependent: :destroy
  has_many :tags, through: :post_tags, class_name: "Blogging::Tag"
  # add has_many associations above.

  # add attachments above.

  scope :published, -> { where(status: :published) }
  scope :drafts, -> { where(status: :draft) }
  scope :archived, -> { where(status: :archived) }
  # add scopes above.

  validates :title, presence: true
  validates :body, presence: true
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
