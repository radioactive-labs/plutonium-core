class User < ResourceRecord
  include Rodauth::Rails.model(:user)

  # add concerns above.

  # add model configurations above.

  # add belongs_to associations above.

  # add has_one associations above.

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
