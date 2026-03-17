class Catalog::ProductMetadataPolicy < Catalog::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:meta_title, :meta_description, :meta_keywords, :og_image_url, :product]
  end

  def permitted_attributes_for_read
    [:meta_title, :meta_description, :meta_keywords, :og_image_url, :product]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
