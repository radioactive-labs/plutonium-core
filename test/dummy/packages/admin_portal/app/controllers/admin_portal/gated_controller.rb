module AdminPortal
  # Exercises the one-time wizard gate (§9). Access to #index is gated behind the
  # one-time WelcomeWizard: an un-completed user is bounced into the wizard (and
  # their destination stashed in session[:return_to]); a completed user passes
  # through.
  class GatedController < PlutoniumController
    include Plutonium::Wizard::Gate

    ensure_wizard_completed ::WelcomeWizard

    def index
      render plain: "gated ok"
    end
  end
end
