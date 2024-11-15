# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class StandardGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Set up standardrb"

      def start
        bundle "standard", version: ">= 1.35.1", group: :development
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
