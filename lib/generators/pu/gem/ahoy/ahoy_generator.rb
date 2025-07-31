# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class AhoyGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Set up Ahoy Matey for tracking visits and events"

      def start
        add_ahoy_matey
        install_ahoy_and_run_migrations
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def add_ahoy_matey
        bundle "ahoy_matey"
      end

      def install_ahoy_and_run_migrations
        run "rails generate ahoy:install"
        run "rails db:migrate"
      end
    end
  end
end
