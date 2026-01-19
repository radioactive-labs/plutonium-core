class DemoFeatures::ReviewDefinition < DemoFeatures::ResourceDefinition
  # Search
  search do |scope, query|
    scope.where("title LIKE :q OR body LIKE :q", q: "%#{query}%")
  end

  # Scopes
  scope :verified
  scope :approved
  scope :pending, default: true

  # Filters
  filter :rating, with: :select, choices: (1..5).to_a
  filter :verified, with: :boolean
  filter :product, with: :association, class_name: DemoFeatures::Product
  filter :approved_at, with: :date_range

  # Sorting
  sorts :rating, :created_at, :approved_at
  default_sort :created_at, :desc

  # Fields
  field :product, as: :association
  field :user, as: :association
  field :title, as: :string
  field :body, as: :text
  input :body, as: :markdown
  field :rating, as: :integer
  input :rating, as: :select, collection: (1..5).to_a
  field :verified, as: :boolean
  input :verified, as: :checkbox
  field :approved_at, as: :datetime

  # Columns
  column :product
  column :title
  column :rating do |review|
    "★" * review.rating + "☆" * (5 - review.rating)
  end
  column :verified
  column :approved_at
  column :user
end
