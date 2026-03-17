class Catalog::ReviewPolicy < Catalog::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:title, :body, :rating, :verified, :product, :user]
  end

  def permitted_attributes_for_read
    [:title, :body, :rating, :verified, :product, :user]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
