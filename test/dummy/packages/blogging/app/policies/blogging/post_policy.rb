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

  def export_csv?
    true
  end

  # Custom actions
  #
  # Record-action policy methods always receive a record instance, so plain
  # state checks suffice. Core permissions are different: read? backs both
  # show? (instance) and index? (collection routes, where `record` is the
  # resource CLASS) — custom logic in read? must handle both.

  def publish? = record.draft?

  def archive? = record.published?

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

  # Tailor the CSV export columns (id is always prepended automatically)
  def permitted_attributes_for_export
    [:title, :status, :user, :created_at]
  end

  # Associations

  def permitted_associations
    %i[comments post_detail post_tags tags]
  end
end
