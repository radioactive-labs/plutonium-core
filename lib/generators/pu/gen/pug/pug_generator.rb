# frozen_string_literal: true

return unless PlutoniumGenerators.cli?

module Pu
  module Gen
    class PugGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Create a new pug"

      argument :name
      class_option :desc, type: :string, desc: "Description of your pug"

      def start
        template "pug.rb.tt", "lib/generators/pu/#{pug_path}/#{pug_class.underscore}.rb"
        create_file "lib/generators/pu/#{pug_path}/templates/.keep"
      end

      def rubocop
        run "standardrb --fix"
      end

      protected

      def pug_name
        name.split(":").map(&:camelize).join("::")
      end

      def pug_path
        pug_name.underscore
      end

      def pug_module
        pug_name.deconstantize
      end

      def pug_class
        "#{pug_name.demodulize}Generator"
      end

      def lib_path
        depth = name.split(":").count
        base = ([".."] * depth).join "/"
        "#{base}/lib/plutonium_generators"
      end
    end
  end
end
