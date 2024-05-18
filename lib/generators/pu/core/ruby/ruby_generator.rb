# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Core
    class RubyGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set ruby version for project"
      class_option :version, type: :string, desc: "Ruby version", default: "3.3.0"

      def start
        set_ruby_version! version
        say "Ruby version set to #{version}"
        say "Run `bundle install` to update your dependencies"
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def version
        options[:version]
      end
    end
  end
end
