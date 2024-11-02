# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class RedisGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Set up redis"

      def start
        bundle "redis"
        bundle "hiredis"
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
