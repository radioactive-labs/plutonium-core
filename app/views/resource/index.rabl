collection @resource_records, root: resource_class.to_s.demodulize.underscore.pluralize.to_sym, object_root: false

attributes :id
attributes(*current_policy.permitted_attributes_for_index)
attributes :created_at, :updated_at

node(:url) { |resource| resource_url_for(resource) }
