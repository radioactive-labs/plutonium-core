class OrganizationUser < ::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  enum :role, member: 0, owner: 1
  # add model configurations above.

  belongs_to :organization
  belongs_to :user
  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  # add scopes above.
  validates :user, uniqueness: {scope: :organization_id, message: "is already a member of this entity"}

  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
