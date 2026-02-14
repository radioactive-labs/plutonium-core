# frozen_string_literal: true

module Pu
  module Rodauth
    module Concerns
      module GemHelpers
        private

        def gem_in_bundle?(name)
          in_root do
            return true if File.exist?("Gemfile") && File.read("Gemfile").match?(/gem ['"]#{name}['"]/)
            return true if File.exist?("Gemfile.lock") && File.read("Gemfile.lock").include?("    #{name} ")
          end
          false
        end
      end
    end
  end
end
