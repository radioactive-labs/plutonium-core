# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Eject
    class ShellGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Eject layout shell (i.e header, sidebar) into your own project"

      def start
        destination_dir = (destination_portal == "main_app") ? "app/views/" : "packages/#{destination_portal}/app/views"
        [
          "plutonium/_resource_header.html.erb",
          "plutonium/_resource_sidebar.html.erb"
        ].each do |file|
          copy_file Plutonium.root.join("app", "views", file), Rails.root.join(destination_dir, file)
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def destination_portal
        portal_option(:dest, prompt: "Select destination portal")
      end

      def copy_file(source_path, destination_path)
        if File.exist?(source_path)
          FileUtils.mkdir_p(File.dirname(destination_path))
          FileUtils.cp(source_path, destination_path)
          say_status("info", "Copied #{source_path} to #{destination_path}", :green)
        else
          say_status("error", "Source file #{source_path} does not exist", :red)
        end
      end
    end
  end
end
