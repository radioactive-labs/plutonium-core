# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Skills
    class SyncGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Sync Claude Code skills from Plutonium into your project"

      def start
        source_dir = Plutonium.root.join(".claude", "skills")
        destination_dir = Rails.root.join(".claude", "skills")

        unless File.directory?(source_dir)
          say_status("error", "Source skills directory not found: #{source_dir}", :red)
          return
        end

        # Create destination directory if it doesn't exist
        FileUtils.mkdir_p(destination_dir)

        # Get all skill directories
        skill_dirs = Dir.children(source_dir).select { |f| File.directory?(source_dir.join(f)) }

        if skill_dirs.empty?
          say_status("info", "No skills found to sync", :yellow)
          return
        end

        say_status("info", "Syncing #{skill_dirs.size} skills from Plutonium...", :blue)

        skill_dirs.each do |skill_name|
          sync_skill(source_dir, destination_dir, skill_name)
        end

        say_status("success", "Skills synced successfully!", :green)
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def sync_skill(source_dir, destination_dir, skill_name)
        source_skill_dir = source_dir.join(skill_name)
        dest_skill_dir = destination_dir.join(skill_name)

        # Create skill directory
        FileUtils.mkdir_p(dest_skill_dir)

        # Copy all files in the skill directory
        Dir.glob(source_skill_dir.join("*")).each do |source_file|
          next unless File.file?(source_file)

          filename = File.basename(source_file)
          dest_file = dest_skill_dir.join(filename)

          FileUtils.cp(source_file, dest_file)
        end

        say_status("synced", skill_name, :green)
      end
    end
  end
end
