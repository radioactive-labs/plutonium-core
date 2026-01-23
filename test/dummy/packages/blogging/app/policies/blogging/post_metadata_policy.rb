class Blogging::PostMetadataPolicy < Blogging::ResourcePolicy
  def create?
    true
  end

  def read?
    true
  end

  def permitted_attributes_for_create
    [:seo_title, :seo_description, :canonical_url, :post]
  end

  def permitted_attributes_for_read
    [:seo_title, :seo_description, :canonical_url, :post]
  end

  def permitted_associations
    %i[]
  end
end
