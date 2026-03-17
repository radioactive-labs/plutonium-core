class Blogging::PostDetailPolicy < Blogging::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:seo_title, :seo_description, :canonical_url, :post]
  end

  def permitted_attributes_for_read
    [:seo_title, :seo_description, :canonical_url, :post]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
