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
      include Plutonium::Wizard::Controller
    end
  end
end
