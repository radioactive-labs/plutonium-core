# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    # Installs actual_db_schema, which tracks phantom migrations across git
    # branches so switching branches with diverging migration sets doesn't
    # leave db/schema.rb out of sync.
    #
    # https://github.com/share-group/actual_db_schema
    class ActualDbSchemaGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Install the actual_db_schema gem"

      def start
        bundle "actual_db_schema", group: %i[development test]
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
