OrgPortal::Engine.routes.draw do
  root to: "dashboard#index"

  # A CONTEXT-anchored (`anchored via:`) portal-level wizard — its anchor is the
  # tenant resolved via `current_scoped_entity`, so it mounts here (no URL :id).
  register_wizard ::ConfigureOrgWizard, at: "configure"

  # Organization is registered as singular to test URL generation when the entity scope model
  # is also a registered resource (creates nested routes that can shadow top-level routes).
  register_resource ::Organization, singular: true
  register_resource ::User, singular: true
  register_resource ::Comment
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
  register_resource ::Widget
  register_resource ::KitchenSink
  register_resource ::UserProfile, singular: true
  # register resources above.

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end

# mount our app
Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:user) do
    # Bare `/org` has no route under path scoping (the root is
    # `/org/:organization_scoped`). Resolve the user's entity and redirect
    # into the scoped portal. Declared BEFORE the mount so the exact `/org`
    # match wins; `/org/<id>/...` still falls through to the engine.
    get "/org", to: "home#index"
    mount OrgPortal::Engine, at: "/org"
  end
end
