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

  def self.development?
    ActiveModel::Type::Boolean.new.cast(ENV["PLUTONIUM_DEV"]).present?
  end

  def self.stylesheet_link
    if development?
      base_dir = "/plutonium-assets/build"
      manifest = "css.dev.manifest"
      filename = "plutonium-dev.css"
    else
      base_dir = "/plutonium-assets"
      manifest = "css.manifest"
      filename = "plutonium.css"
    end

    file = JSON.parse(File.read(root.join(manifest)))[filename]
    "#{base_dir}/#{file}"
  end

  def self.script_link
    filename = "plutonium-app.js"
    if development?
      base_dir = "/plutonium-assets/build"
      manifest = "js.dev.manifest"
    else
      base_dir = "/plutonium-assets"
      manifest = "js.manifest"
    end

    file = JSON.parse(File.read(root.join(manifest)))[filename]
    "#{base_dir}/#{file}"
  end

  def self.favicon_link
    "/plutonium-assets/plutonium.ico"
  end

  def self.logo_link
    "/plutonium-assets/plutonium-logo.png"
  end
end

Plutonium::ZEITWERK_LOADER = loader
