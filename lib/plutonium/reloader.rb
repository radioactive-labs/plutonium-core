# Based on:
# https://avohq.io/blog/auto-reload-rails-initializers-and-other-files-in-development
module Plutonium
  class Reloader
    delegate :execute_if_updated, :execute, :updated?, to: :updater

    def reload!
      # reload all files declared in paths
      files.each { |file| load file }

      # reload all files declared in each directory
      directories.keys.each do |dir|
        Dir.glob("#{dir}/**/*.rb".to_s).each { |file| load file }
      end
    end

    private
      def updater
        @updater ||= config.file_watcher.new(files, directories) { reload! }
      end

      def files
        # debugger
        # we want to watch some files no matter what
        paths = [
          # Rails.root.join("packages", "**", "lib", "engine.rb"),
        ]

        # we want to watch some files only in Avo development
        if reload_lib?
          paths += []
        end

        paths
      end

      def directories
        dirs = {}

        # watch the lib directory in Avo development
        if reload_lib?
          dirs[Plutonium.lib_root.to_s] = ["rb"]
        end

        dirs
      end

      def config
        Rails.application.config
      end

      def reload_lib?
        # Avo::IN_DEVELOPMENT || ENV['AVO_RELOAD_LIB_DIR']
        true
      end
  end
end
