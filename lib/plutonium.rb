require "zeitwerk"

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/plutonium/railtie.rb")
loader.enable_reloading if defined?(Rails.env) && Rails.env.development?
loader.setup

require_relative "plutonium/railtie" if defined?(Rails::Railtie)

module Plutonium
  class Error < StandardError; end

  def self.root
    Pathname.new File.expand_path("../", __dir__)
  end

  def self.lib_root
    root.join("lib", "plutonium")
  end

  def self.stylesheet_link
    if Plutonium::Config.development
      file = JSON.parse(File.read(root.join("css.manifest")))["plutonium-dev.css"]
      "/plutonium-assets/build/#{file}"
    else
      raise NotImplementedError, "TODO: implement asset resolution for prod"
      # @stylesheet ||= begin
      #   file = JSON.parse(File.read(root.join("css.manifest")))["plutonium.css"]
      #   "/plutonium-assets/#{file}"
      # end
    end
  end

  def self.script_link
    if Plutonium::Config.development
      file = JSON.parse(File.read(root.join("js.manifest")))["plutonium.js"]
      "/plutonium-assets/build/#{file}"
    else
      raise NotImplementedError, "TODO: implement asset resolution for prod"
      # @stylesheet ||= begin
      #   file = JSON.parse(File.read(root.join("css.manifest")))["plutonium.css"]
      #   "/plutonium-assets/#{file}"
      # end
    end
  end
end

Plutonium::ZEITWERK_LOADER = loader
