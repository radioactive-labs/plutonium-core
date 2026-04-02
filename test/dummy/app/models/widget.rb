class Widget < ::ResourceRecord
  belongs_to :organization

  validates :name, presence: true
end
