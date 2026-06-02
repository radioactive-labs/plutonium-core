# frozen_string_literal: true

# Bridges a freshly-authenticated user into the path-scoped OrgPortal.
# The portal's only root is `/org/:organization_scoped` (e.g. `/org/1`) —
# there is no bare `/org` — so something outside the entity scope has to
# resolve which Organization to load. This is the minimal version of what
# `pu:saas:welcome` generates (no multi-org picker / onboarding): land the
# user on their first organization's scoped root.
class HomeController < ApplicationController
  include Plutonium::Auth::Rodauth(:user)

  before_action { rodauth.require_authentication }

  def index
    organization = current_user.organizations.first

    unless organization
      render plain: "#{current_user.email} isn't a member of any organization yet.", status: :not_found
      return
    end

    redirect_to OrgPortal::Engine.routes.url_helpers.organization_scoped_root_path(organization_scoped: organization)
  end
end
