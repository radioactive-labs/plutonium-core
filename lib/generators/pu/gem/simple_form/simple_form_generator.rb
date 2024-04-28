# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class SimpleFormGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Install SimpleForm"

      def start
        Bundler.with_unbundled_env do
          run "bundle add simple_form"
        end

        directory "config"
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
