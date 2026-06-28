# frozen_string_literal: true

module Plutonium
  module Wizard
    # Convenience base for a standalone wizard controller that needs NO custom auth
    # base: a plain `ActionController::Base` plus the wizard module. Use it when you
    # want to drop in your own controller without an auth concern:
    #
    #   class WizardsController < Plutonium::Wizard::BaseController; end
    #
    # For an AUTHENTICATED standalone wizard, don't use this — inherit your own
    # authenticated base and `include Plutonium::Wizard::Controller` instead, so the
    # controller carries `current_user`:
    #
    #   class WizardsController < ApplicationController
    #     include Plutonium::Wizard::Controller
    #     include Plutonium::Auth::Rodauth(:user)
    #   end
    #
    # The module is the mechanism; this class is only sugar.
    class BaseController < ActionController::Base
      # A bare `ActionController::Base` host normally inherits forgery protection
      # from the app's `default_protect_from_forgery`, but make it explicit here so
      # a standalone wizard mount is CSRF-protected regardless of app config (the
      # wizard `update` is a state-changing POST).
      protect_from_forgery with: :exception

      include Plutonium::Wizard::Controller
    end
  end
end
