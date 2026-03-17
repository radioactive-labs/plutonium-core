class LocusPortal::Blogging::TutorialPolicy < ::ResourcePolicy
  include LocusPortal::ResourcePolicy

  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:title, :body, :status]
  end

  def permitted_attributes_for_read
    [:title, :body, :status, :created_at, :updated_at]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
