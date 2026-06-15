# frozen_string_literal: true

# A hand-written dummy wizard (authored like an interaction) exercising the
# portal-hosted controller + register_wizard routing in integration tests.
#
# Non-anchored create flow: collect a name, then a detail, then review; `execute`
# creates an Organization atomically.
class OnboardOrganizationWizard < Plutonium::Wizard::Base
  presents label: "Onboard an organization"

  step :identity do
    attribute :name, :string
    input :name
    validates :name, presence: true
  end

  step :details do
    attribute :note, :string
    input :note
  end

  review label: "Review"

  def execute
    org = Organization.create!(name: data.name)
    succeed(org).with_message("Organization onboarded")
  end
end
