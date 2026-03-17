class Catalog::ReviewDefinition < Catalog::ResourceDefinition
  scope :verified
  scope :pending_verification

  filter :rating, with: :select, choices: (1..5).to_a
  filter :verified, with: :boolean
  filter :product, with: :association, class_name: "Catalog::Product"

  sort :rating
  sort :created_at
  default_sort :created_at, :desc
end
