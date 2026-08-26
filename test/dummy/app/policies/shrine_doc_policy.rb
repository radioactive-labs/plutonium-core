class ShrineDocPolicy < ::ResourcePolicy
  def permitted_attributes_for_create
    [:title, :file, :banner]
  end

  def permitted_attributes_for_read
    [:title, :file, :banner, :created_at, :updated_at]
  end
end
