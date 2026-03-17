LocusPortal::Engine.routes.draw do
  root to: "dashboard#index"

  register_resource ::Blogging::Post
  register_resource ::Blogging::Tag
  register_resource ::Blogging::PostDetail
  register_resource ::Blogging::PostTag
  register_resource ::Blogging::Article
  register_resource ::Blogging::Tutorial
  register_resource ::Catalog::Product
  register_resource ::Catalog::Category
  register_resource ::Catalog::Review
  register_resource ::Catalog::Variant
  register_resource ::Catalog::ProductDetail
  register_resource ::Comment
  register_resource ::User, singular: true
  register_resource ::UserProfile, singular: true
  # register resources above.

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end

# mount our app
Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:user) do
    mount LocusPortal::Engine, at: "/locus"
  end
end
