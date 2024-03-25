# frozen_string_literal: true

require "plutonium_generators"

module Pu
  module Res
    class ScaffoldGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Scaffold a resource"

      argument :name

      def start
      rescue => e
        exception "Resource scaffold failed:", e
      end
    end
  end
end
