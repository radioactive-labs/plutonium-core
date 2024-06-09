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
    @application_name || Rails.application.class.module_parent.name
  end

  def self.application_name=(application_name)
    @application_name = application_name
  end

  def self.development?
    ActiveModel::Type::Boolean.new.cast(ENV["PLUTONIUM_DEV"]).present?
  end

  def self.eager_load_rails!
    return if Rails.env.production? && defined?(@rails_eager_loaded)

    Rails.application.eager_load! unless Rails.application.config.eager_load
    @rails_eager_loaded = true
  end
end

Plutonium::ZEITWERK_LOADER = loader
