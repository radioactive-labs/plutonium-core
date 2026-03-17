class Organization < ::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  # add model configurations above.

  # add belongs_to associations above.

  # add has_one associations above.

  has_many :organization_users, dependent: :destroy
  has_many :users, through: :organization_users
  # add has_many associations above.

  # add attachments above.

  # add scopes above.

  validates :name, presence: true, uniqueness: true
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
