# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class DotenvGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set up dotenv"

      def start
        in_root do
          [".env", ".env.local", ".env.template", ".env.local.template"].each do |file|
            copy_file file
          end

          copy_file "config/initializers/001_ensure_required_env.rb"

          insert_into_file "Gemfile", "\ngem \"dotenv\", :groups => [:development, :test]\n", after: /^gem ["']rails["'].*\n/
          bundle!
        end
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
