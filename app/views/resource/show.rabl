object @resource_record

attributes :id
attributes(*current_policy.permitted_attributes_for_show)
attributes :created_at, :updated_at

node(:url) { |resource| resource_url_for(resource) }
