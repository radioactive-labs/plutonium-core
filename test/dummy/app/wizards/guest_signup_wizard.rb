# frozen_string_literal: true

# A GUEST (anonymous) wizard (§4.5): it runs WITHOUT a logged-in user, mounted on
# a PUBLIC route (pre-login) via `register_wizard ..., public: true` (the default
# for an `anonymous` wizard). A signup-style flow whose terminal `execute` creates
# the account — the ONE place a guest wizard may cross the auth boundary. There is
# no mid-flow auth transition.
#
# Its identity is the server-minted `wizard_token` (httponly/secure/same_site
# cookie), cleared on completion. No `concurrency_key` → tokened/repeatable.
class GuestSignupWizard < Plutonium::Wizard::Base
  presents label: "Sign up"

  anonymous

  step :account do
    attribute :name, :string
    input :name
    validates :name, presence: true
  end

  review label: "Review"

  # The terminal boundary: create the account. A real signup would also sign the
  # user in here (the host calls Rodauth, which rotates the Rails session); the
  # framework needs no special handling beyond letting `execute` run.
  def execute
    org = Organization.create!(name: data.name)
    succeed(org).with_message("Welcome!")
  end
end
