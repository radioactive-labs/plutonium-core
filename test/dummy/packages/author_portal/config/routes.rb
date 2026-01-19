AuthorPortal::Engine.routes.draw do
  root to: "dashboard#index"

  register_resource ::Blogging::Post
  # register resources above.

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end

# mount our app
Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:user) do
    mount AuthorPortal::Engine, at: "/author"
  end
end
