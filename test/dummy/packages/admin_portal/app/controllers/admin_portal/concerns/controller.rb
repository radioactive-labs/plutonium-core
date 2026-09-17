module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:admin)

      # add concerns above.

      included do
        around_action :switch_locale
      end

      # Demonstrates the i18n layer: the EN | ES links in the top bar
      # (_resource_header.html.erb) pass ?locale=, which we remember in the
      # session so every later request stays in the chosen language.
      def switch_locale(&)
        session[:locale] = params[:locale] if params[:locale].present?
        locale = session[:locale].to_s.to_sym
        locale = I18n.default_locale unless I18n.available_locales.include?(locale)
        I18n.with_locale(locale, &)
      end
    end
  end
end
