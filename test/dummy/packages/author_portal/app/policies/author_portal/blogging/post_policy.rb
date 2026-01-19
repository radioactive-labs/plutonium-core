class AuthorPortal::Blogging::PostPolicy < ::Blogging::PostPolicy
  # Authors can only see their own posts
  def relation_scope(relation)
    relation.where(user_id: user.id)
  end

  # Authors can always create posts
  def create?
    true
  end

  # Authors can only update their own posts
  def update?
    owner?
  end

  # Authors can only delete their own posts
  def destroy?
    owner?
  end

  # Don't show user_id field - it's automatically set
  def permitted_attributes_for_create
    [:title, :body]
  end
end
