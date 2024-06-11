# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Gem
    class AnnotateGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Install the annnotate gem"

      def start
        bundle "annotate", group: :development
        copy_file "lib/tasks/auto_annotate_models.rake"
      rescue => e
        exception "#{self.class} failed:", e
      end
    end
  end
end
