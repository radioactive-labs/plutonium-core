class DemoPortal::Blogging::PostMetadataPolicy < ::ResourcePolicy
  include DemoPortal::ResourcePolicy

  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:seo_title, :seo_description, :canonical_url]
  end

  def permitted_attributes_for_read
    [:seo_title, :seo_description, :canonical_url, :created_at, :updated_at]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
