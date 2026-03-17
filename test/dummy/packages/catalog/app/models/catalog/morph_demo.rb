require_relative "../catalog"

class Catalog::MorphDemo < Catalog::ResourceRecord
  # add concerns above.

  # add constants above.

  enum :record_type, {simple: 0, detailed: 1, scheduled: 2}
  # add enums above.

  # add model configurations above.

  belongs_to :category, class_name: "Catalog::Category"
  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  scope :associated_with_organization, ->(organization) {
    joins(:category).merge(Catalog::Category.associated_with_organization(organization))
  }
  # add scopes above.

  validates :name, presence: true
  validates :status, presence: true
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
