attributes :id
attributes :created_at, :updated_at

node(:sgid) { |resource| resource.to_signed_global_id.to_s }

# Serialize attributes, converting associations to nested objects
permitted_attributes.each do |attr|
  reflection = resource_class.reflect_on_association(attr)

  if reflection
    # Serialize association as ID(s) and sgid(s)
    case reflection.macro
    when :belongs_to
      # Use foreign key directly for belongs_to
      node(:"#{attr}_id") do |resource|
        resource.public_send(reflection.foreign_key)
      end
      # Include sgid for form submissions
      node(:"#{attr}_sgid") do |resource|
        resource.public_send(:"#{attr}_sgid")&.to_s
      end
    when :has_many, :has_and_belongs_to_many
      # Return array of IDs for collections
      node(:"#{attr.to_s.singularize}_ids") do |resource|
        resource.public_send(attr).pluck(:id)
      end
      # Include sgids for form submissions
      node(:"#{attr.to_s.singularize}_sgids") do |resource|
        resource.public_send(:"#{attr.to_s.singularize}_sgids").map(&:to_s)
      end
    when :has_one
      # Return single ID for has_one
      node(:"#{attr}_id") do |resource|
        associated_record = resource.public_send(attr)
        associated_record&.id
      end
      # Include sgid for form submissions
      node(:"#{attr}_sgid") do |resource|
        resource.public_send(:"#{attr}_sgid")&.to_s
      end
    end
  else
    # Regular attribute
    attributes attr
  end
end

node(:url) { |resource| resource_url_for(resource) }
