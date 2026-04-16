class Blogging::PostPolicy < Blogging::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  def update?
    true
  end

  def destroy?
    true
  end

  # Custom actions

  def publish?
    record.is_a?(Blogging::Post) && record.draft?
  end

  def archive?
    record.is_a?(Blogging::Post) && record.published?
  end

  def touch?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:title, :body, :user, :author, :editor, :organization, :status]
  end

  def permitted_attributes_for_read
    [:title, :body, :user, :author, :editor, :organization, :status, :created_at]
  end

  # Associations

  def permitted_associations
    %i[comments post_detail post_tags tags]
  end
end
