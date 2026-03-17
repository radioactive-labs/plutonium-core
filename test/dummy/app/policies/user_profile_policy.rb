class UserProfilePolicy < ::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:display_name, :bio, :timezone, :locale, :user]
  end

  def permitted_attributes_for_read
    [:display_name, :bio, :timezone, :locale, :user]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
