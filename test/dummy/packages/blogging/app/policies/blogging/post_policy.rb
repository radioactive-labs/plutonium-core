class Blogging::PostPolicy < Blogging::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    return true unless record_instance?

    record.published? || owner?
  end

  def update?
    owner?
  end

  def destroy?
    owner?
  end

  # Custom actions
  def publish?
    owner? && !record.published?
  end

  # Core attributes

  def permitted_attributes_for_create
    [:title, :body, :user_id]
  end

  def permitted_attributes_for_update
    if owner?
      [:title, :body, :published]
    else
      []
    end
  end

  def permitted_attributes_for_index
    [:title, :body, :published, :created_at, :user]
  end

  def permitted_attributes_for_show
    if owner? || record.published?
      [:title, :body, :published, :created_at, :user]
    else
      [:title]
    end
  end

  # Scope - which records appear in listings
  def relation_scope(relation)
    if user.is_a?(Admin)
      relation # Admins see everything
    else
      relation.where(published: true).or(relation.where(user_id: user.id))
    end
  end

  # Associations

  def permitted_associations
    %i[user comments]
  end

  private

  def record_instance?
    record.is_a?(Blogging::Post)
  end

  def owner?
    record_instance? && record.user_id == user.id
  end
end
