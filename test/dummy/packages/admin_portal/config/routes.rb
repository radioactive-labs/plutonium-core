AdminPortal::Engine.routes.draw do
  root to: "dashboard#index"

  register_wizard ::OnboardOrganizationWizard, at: "onboarding"
  # Mounted at a path that deliberately DIFFERS from the wizard's class slug
  # (`welcome`) so the gate must resolve the route by the `wizard_class` default,
  # not by re-deriving a slug from the class name (which would 404 / raise).
  register_wizard ::WelcomeWizard, at: "welcome_aboard"
  register_wizard ::ChromelessWizard, at: "chromeless"

  # A branching wizard whose hidden step has a side-effecting on_submit — used to
  # prove a POST to an unreachable (branch-hidden) step is refused before it runs.
  register_wizard ::BranchGuardWizard, at: "branch-guard"

  # An `anonymous` (guest) wizard mounted on a PUBLIC route (pre-login). Because
  # the portal engine is mounted behind the host's auth constraint, this draws on
  # the MAIN app route set instead (outside the constraint) — see §4.5 / the
  # `public:` option. `public: true` is the default for `anonymous` wizards.
  register_wizard ::GuestSignupWizard, at: "signup", public: true

  # A page gated behind the one-time WelcomeWizard (see GatedController).
  get "gated", to: "gated#index"

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
  register_resource ::Catalog::Spec
  register_resource ::NetworkDevice
  register_resource ::UserProfile
  register_resource ::KitchenSink
  register_resource ::Widget
  register_resource ::Task
  register_resource ::ShrineDoc
  # register resources above.
end

Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:admin) do
    mount AdminPortal::Engine, at: "/admin"
  end
end
