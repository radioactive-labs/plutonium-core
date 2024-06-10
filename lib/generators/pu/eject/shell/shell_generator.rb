# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Eject
    class ShellGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Eject layout shell (i.e header, sidebar) into your own project"

      class_option :dest, type: :string

      def start
        destination_dir = (destination_app == "main_app") ? "app/views/" : "packages/#{destination_app}/app/views/#{destination_app}"
        [
          "application/_resource_header.html.erb",
          "application/_resource_sidebar.html.erb"
        ].each do |file|
          copy_file Plutonium.root.join("app", "views", file), Rails.root.join(destination_dir)
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def destination_app
        @destination_app || select_app(options[:dest], msg: "Select destination app")
      end

      def copy_file(source_path, destination_path)
        if File.exist?(source_path)
          FileUtils.cp(source_path, destination_path)
          say_status("info", "Copied #{source_path} to #{destination_path}", :green)
        else
          say_status("error", "Source file #{source_path} does not exist", :red)
        end
      end
    end
  end
end
