# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class StandardGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Set up standardrb"

      def start
        add_standard
        remove_rubocop_rails_omakase
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def add_standard
        bundle "standard", version: ">= 1.35.1", group: :development
      end

      def remove_rubocop_rails_omakase
        run "bundle remove rubocop-rails-omakase"
        gsub_file "Gemfile", /\n.*\n.*# Omakase Ruby styling.*/, ""
        remove_file ".rubocop.yml"
      end
    end
  end
end
