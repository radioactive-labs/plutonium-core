class Task < ::ResourceRecord
  include Plutonium::Positioning
  # add concerns above.

  # add constants above.

  # add enums above.

  positioned_on :position, scope: :status
  # add model configurations above.

  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  # add scopes above.

  validates :title, presence: true
  validates :status, presence: true
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
