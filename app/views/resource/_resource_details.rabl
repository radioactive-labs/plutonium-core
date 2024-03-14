attributes :id
attributes(*permitted_attributes)
attributes :created_at, :updated_at

node(:url) { |resource| resource_url_for(resource) }
