require_relative "../blogging"

class Blogging::Comment < Blogging::ResourceRecord
  # add concerns above.

  # add constants above.

  # add enums above.

  # add model configurations above.

  belongs_to :user
  belongs_to :post, class_name: "Blogging::Post"
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
