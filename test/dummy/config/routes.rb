Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # A MAIN-APP (portal-less) authenticated wizard, mounted directly on the
  # application route set — the standalone-onboarding shape. Auth comes from
  # ::PlutoniumController (Rodauth(:user)); the synthesized top-level
  # `WizardsController` is distinct from the public `PublicWizardsController`.
  register_wizard ::MainAppOnboardingWizard, at: "onboarding"

  # A wizard exercising attachment fields against BOTH backends (ActiveStorage +
  # active_shrine). The Shrine direct-upload endpoint is mounted here; ActiveStorage's
  # `/rails/active_storage/direct_uploads` is auto-mounted by its engine.
  register_wizard ::AttachmentDemoWizard, at: "uploads"
  mount Shrine.upload_endpoint(:cache) => "/shrine/upload"

  # A wizard exercising STAGE-PHASE attachment validation via a per-field Shrine
  # `uploader:` (LimitedUploader's max-size rule is enforced on the step).
  register_wizard ::ValidatedUploadWizard, at: "validated-upload"

  # Defines the root path route ("/")
  # Bridges authenticated users into the path-scoped OrgPortal. This is
  # also where rodauth's `login_redirect "/"` lands after sign-in.
  root "home#index"
end
