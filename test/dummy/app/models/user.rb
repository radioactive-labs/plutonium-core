class User < ResourceRecord
  include Rodauth::Rails.model(:user)

  # add concerns above.

  # add model configurations above.

  # add belongs_to associations above.

  # add has_one associations above.

  has_many :authored_posts, class_name: "Blogging::Post", foreign_key: :author_id, inverse_of: :author, dependent: :nullify
  has_many :edited_posts, class_name: "Blogging::Post", foreign_key: :editor_id, inverse_of: :editor, dependent: :nullify
  # add has_many associations above.

  # add attachments above.

  # add scopes above.

  validates :email, presence: true
  # add validations above.

  # add callbacks above.

  # add delegations above.

  enum :status, unverified: 1, verified: 2, closed: 3
  # add misc attribute macros above.

  # add methods above.
end
