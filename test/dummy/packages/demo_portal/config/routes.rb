DemoPortal::Engine.routes.draw do
  root to: "dashboard#index"

  register_resource ::DemoFeatures::Category
  register_resource ::DemoFeatures::MorphDemo
  register_resource ::DemoFeatures::Tag
  register_resource ::DemoFeatures::Product
  register_resource ::DemoFeatures::ProductTag
  register_resource ::DemoFeatures::Variant
  register_resource ::DemoFeatures::Review
  # register resources above.

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end

# mount our app
Rails.application.routes.draw do
  mount DemoPortal::Engine, at: "/demo"
end
