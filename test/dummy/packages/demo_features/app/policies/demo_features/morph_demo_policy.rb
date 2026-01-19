class DemoFeatures::MorphDemoPolicy < DemoFeatures::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  def conditional_form_demo?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:category, :record_type, :name, :status, :priority, :scheduled_at, :description, :phone]
  end

  def permitted_attributes_for_read
    [:category, :record_type, :name, :status, :priority, :scheduled_at, :description, :phone]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
