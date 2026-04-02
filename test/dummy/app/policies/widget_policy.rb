class WidgetPolicy < ResourcePolicy
  def permitted_attributes_for_create
    [:name, :organization]
  end

  def permitted_attributes_for_read
    [:name, :organization]
  end

  def permitted_associations
    %i[]
  end
end
