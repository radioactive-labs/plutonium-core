class Blogging::CommentPolicy < Blogging::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:body, :user, :post]
  end

  def permitted_attributes_for_read
    [:body, :user, :post]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
