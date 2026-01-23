DemoPortal::Engine.routes.draw do
  root to: "dashboard#index"

  register_resource ::DemoFeatures::Category
  register_resource ::DemoFeatures::MorphDemo
  register_resource ::DemoFeatures::Tag
  register_resource ::DemoFeatures::Product
  register_resource ::DemoFeatures::ProductTag
  register_resource ::DemoFeatures::Variant
  register_resource ::DemoFeatures::Review
  register_resource ::Blogging::Comment
  register_resource ::Blogging::Post
  register_resource ::Blogging::PostMetadata
  register_resource ::Admin
  register_resource ::User
  # register resources above.

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end

# mount our app
Rails.application.routes.draw do
  mount DemoPortal::Engine, at: "/demo"
end
