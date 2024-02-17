# frozen_string_literal: true

attributes :id
attributes(*permitted_attributes)
attributes :created_at, :updated_at

node(:url) { |resource| url_for(adapt_route_args(resource)) }
