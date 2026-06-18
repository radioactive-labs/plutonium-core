# frozen_string_literal: true

# A MAIN-APP (portal-less) authenticated wizard, registered directly on
# `Rails.application.routes` via `register_wizard` — NOT inside a portal engine.
# It proves that an authenticated standalone flow (onboarding / invite acceptance)
# works outside a portal: the synthesized top-level `WizardsController` inherits
# the dummy's `::PlutoniumController`, which wires `Plutonium::Auth::Rodauth(:user)`,
# so `current_user` is the logged-in user account.
class MainAppOnboardingWizard < Plutonium::Wizard::Base
  presents label: "Get started"

  step :profile, label: "Your profile" do
    attribute :display_name, :string
    input :display_name
    validates :display_name, presence: true
  end

  step :preferences, label: "Preferences" do
    attribute :newsletter, :string
    input :newsletter, as: :select, choices: %w[yes no]
    validates :newsletter, presence: true
  end

  review label: "Review & finish"

  def execute
    succeed.with_message("You're all set, #{data.profile.display_name}!")
  end
end
