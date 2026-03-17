AdminPortal::Engine.routes.draw do
  root to: "dashboard#index"

  register_resource ::User
  register_resource ::Organization
  register_resource ::OrganizationUser
  register_resource ::Comment
  register_resource ::Blogging::Post
  register_resource ::Blogging::PostDetail
  register_resource ::Blogging::Tag
  register_resource ::Blogging::PostTag
  register_resource ::Catalog::Category
  register_resource ::Catalog::Product
  register_resource ::Catalog::Variant
  register_resource ::Catalog::ProductDetail
  register_resource ::Catalog::Review
  register_resource ::Blogging::Article
  register_resource ::Blogging::Tutorial
  register_resource ::Catalog::ProductMetadata
  register_resource ::Catalog::MorphDemo
  register_resource ::NetworkDevice
  register_resource ::UserProfile
  # register resources above.
end

Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:admin) do
    mount AdminPortal::Engine, at: "/admin"
  end
end
