TestPortal::Engine.routes.draw do
  root to: "dashboard#index"

  # register resources above.

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end

# mount our app
Rails.application.routes.draw do
  mount TestPortal::Engine, at: "/test"
end
