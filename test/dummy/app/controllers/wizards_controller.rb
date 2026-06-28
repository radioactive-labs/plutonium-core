# An APP-DEFINED main-app wizard controller. Because it exists, `register_wizard`
# on the main app uses it instead of synthesizing a bare one (the override hook).
# It supplies the auth the synthesized bare controller deliberately lacks — here
# the regular-user account — so an AUTHENTICATED main-app (portal-less) wizard
# works. This is the same "app owns the controller" contract as a main-app
# `register_resource` controller.
class WizardsController < ApplicationController
  include Plutonium::Wizard::Controller
  include Plutonium::Auth::Rodauth(:user)
end
