class NetworkDevicePolicy < ::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:name, :external_id, :ip_address, :network_range, :mac_address, :metadata, :location_path]
  end

  def permitted_attributes_for_read
    [:name, :external_id, :ip_address, :network_range, :mac_address, :metadata, :location_path]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
