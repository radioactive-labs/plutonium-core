class Blogging::PostTagPolicy < Blogging::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:position, :post, :tag]
  end

  def permitted_attributes_for_read
    [:position, :post, :tag]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
