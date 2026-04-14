# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Test
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Install Plutonium::Testing scaffolding"

      def install
        add_require_to_test_helper
        copy_support_file
      end

      private

      def add_require_to_test_helper
        helper = "test/test_helper.rb"
        return unless File.exist?(helper)
        line = %(require "plutonium/testing")
        return if File.read(helper).include?(line)
        append_to_file helper, "\n#{line}\n"
      end

      def copy_support_file
        copy_file "plutonium_testing.rb", "test/support/plutonium_testing.rb"
      end
    end
  end
end
