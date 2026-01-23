require_relative "../blogging"

class Blogging::PostMetadata < Blogging::ResourceRecord
  belongs_to :post, class_name: "Blogging::Post"
end
