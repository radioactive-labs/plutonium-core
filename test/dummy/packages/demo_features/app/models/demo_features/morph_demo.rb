require_relative "../demo_features"

class DemoFeatures::MorphDemo < DemoFeatures::ResourceRecord
  # add concerns above.

  # add constants above.

  enum :record_type, {simple: 0, detailed: 1, scheduled: 2}
  # add enums above.

  # add model configurations above.

  belongs_to :category, class_name: "DemoFeatures::Category"
  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  # add scopes above.

  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # add methods above. add private methods below.
end
