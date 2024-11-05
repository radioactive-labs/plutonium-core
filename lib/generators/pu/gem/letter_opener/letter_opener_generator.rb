# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class LetterOpenerGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Set up letter_opener"

      def start
        bundle "letter_opener", group: :development
        environment "config.action_mailer.delivery_method = :letter_opener", env: :development
        environment "config.action_mailer.perform_deliveries = true", env: :development
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
