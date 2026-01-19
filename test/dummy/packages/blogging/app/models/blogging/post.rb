require_relative "../blogging"

class Blogging::Post < Blogging::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  # add model configurations above.

  belongs_to :user
  # add belongs_to associations above.

  # add has_one associations above.

  has_many :comments, foreign_key: :post_id, dependent: :destroy
  # add has_many associations above.

  # add attachments above.

  scope :published, -> { where(published: true) }
  scope :drafts, -> { where(published: [false, nil]) }
  # add scopes above.

  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
