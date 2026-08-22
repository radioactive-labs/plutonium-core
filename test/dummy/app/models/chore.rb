# The Mode B fixture: a positioned resource whose ordering is owned by a
# THIRD-PARTY gem rather than by Plutonium.
#
# Deliberately does NOT `include Plutonium::Positioning::Model` and never calls
# `positioned_on`. That combination — no framework storage, plus a definition
# carrying a `position_on … do |move|` block — is precisely what Mode B exists
# for, and Chore is the only resource in the dummy app that has it. Task (Mode A,
# fractional decimals) covers the framework-owned half.
#
# The pairing is what keeps the worked acts_as_list example in
# docs/reference/resource/positioning.md honest: the definition runs the documented
# snippet verbatim, against the real gem, through the real endpoint.
class Chore < ::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  # 1-based, contiguous, renumbered on every move — the opposite of Plutonium's
  # fractional positions — and grouped by status.
  #
  # The ARRAY form is mandatory here, and the reason is a trap worth naming:
  # acts_as_list runs a bare Symbol scope through `ScopeMethodDefiner.idify`,
  # which appends `_id` to anything that is neither an association nor already
  # `*_id`. `scope: :status` therefore silently becomes `scope: :status_id` and
  # every create dies with `NoMethodError: undefined method 'status_id'`.
  # `scope: [:status]` takes the column literally.
  acts_as_list scope: [:status]
  # add model configurations above.

  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  # add scopes above.

  validates :title, presence: true
  validates :status, presence: true
  # NOTE: deliberately no `validates :position, presence: true` (the scaffold
  # emits one). acts_as_list assigns the rank in a `before_create` callback,
  # which runs AFTER validation, so a presence rule would reject every new row.
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
