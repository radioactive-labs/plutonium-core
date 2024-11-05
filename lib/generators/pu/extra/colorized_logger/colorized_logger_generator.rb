# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Extra
    class ColorizedLoggerGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set up a colorized logger"

      def start
        copy_file "config/initializers/colorized_logger.rb"
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
