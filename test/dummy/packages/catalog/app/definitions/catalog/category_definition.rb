class Catalog::CategoryDefinition < Catalog::ResourceDefinition
  field :description, as: :text

  search do |scope, query|
    scope.where("catalog_categories.name LIKE ?", "%#{query}%")
  end

  sort :name
  sort :created_at
  default_sort :name, :asc
end
