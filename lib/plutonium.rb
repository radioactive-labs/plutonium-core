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

  def self.logger
    Rails.logger
  end

  def self.application_name
    Rails.application.class.module_parent.name
  end

  def self.development?
    ActiveModel::Type::Boolean.new.cast(ENV["PLUTONIUM_DEV"]).present?
  end

  def self.stylesheet_link
    return @stylesheet_link if defined?(@stylesheet_link) && !development?

    if development?
      base_dir = "/plutonium-assets/build"
      filename = "plutonium-dev.css"
    else
      base_dir = "/plutonium-assets"
      filename = "plutonium.css"
    end

    file = stylesheet_manifest[filename]
    @stylesheet_link = "#{base_dir}/#{file}"
  end

  def self.script_link
    return @script_link if defined?(@script_link) && !development?

    filename = "plutonium-app.js"
    base_dir = if development?
      "/plutonium-assets/build"
    else
      "/plutonium-assets"
    end

    file = script_manifest[filename]
    @script_link = "#{base_dir}/#{file}"
  end

  def self.favicon_link
    "/plutonium-assets/plutonium.ico"
  end

  def self.logo_link
    "/plutonium-assets/plutonium-logo.png"
  end

  def self.stylesheet_manifest
    return @stylesheet_manifest if defined?(@stylesheet_manifest) && !development?

    manifest = if development?
      "css.dev.manifest"
    else
      "css.manifest"
    end
    @stylesheet_manifest = JSON.parse(File.read(root.join(manifest)))
  end

  def self.script_manifest
    return @script_manifest if defined?(@script_manifest) && !development?

    manifest = if development?
      "js.dev.manifest"
    else
      "js.manifest"
    end
    @script_manifest = JSON.parse(File.read(root.join(manifest)))
  end
end

Plutonium::ZEITWERK_LOADER = loader
