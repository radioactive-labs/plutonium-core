StorefrontPortal::Engine.routes.draw do
  root to: "dashboard#index"

  register_resource ::Blogging::Post
  register_resource ::Catalog::Product
  register_resource ::Catalog::Category
  # register resources above.

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end

# mount our app
Rails.application.routes.draw do
  mount StorefrontPortal::Engine, at: "/storefront"
end
