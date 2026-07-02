class ShrineDocPolicy < ::ResourcePolicy
  def permitted_attributes_for_create
    [:title, :file]
  end

  def permitted_attributes_for_read
    [:title, :file, :created_at, :updated_at]
  end
end
