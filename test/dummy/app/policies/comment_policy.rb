class CommentPolicy < ::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:body, :commentable, :user]
  end

  def permitted_attributes_for_read
    [:body, :commentable, :user]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
