# frozen_string_literal: true

require "semantic_range"
require "tty-prompt"

module PlutoniumGenerators
  module Generator
    include Concerns::Config
    include Concerns::Logger
    include Concerns::Serializer
    include Concerns::Actions

    # Finds the shared namespace prefix between two model names.
    # Used to derive association names when models share a namespace.
    # e.g., find_shared_namespace("Competition::TeamUser", "Competition::Team") => "competition"
    def self.find_shared_namespace(model1, model2, separator: "/")
      parts1 = model1.underscore.split(separator)
      parts2 = model2.underscore.split(separator)

      shared = []
      [parts1.length, parts2.length].min.times do |i|
        break unless parts1[i] == parts2[i]
        shared << parts1[i]
      end

      shared.empty? ? nil : shared.join(separator)
    end

    # Derives the association name for a reference, stripping shared namespace.
    # e.g., derive_association_name("Competition::TeamUser", "Competition::Team") => "team"
    def self.derive_association_name(from_model, to_model)
      to_parts = to_model.underscore.split("/")

      if (shared = find_shared_namespace(from_model, to_model))
        shared_parts = shared.split("/")
        to_parts = to_parts.drop(shared_parts.length)
      end

      to_parts.join("_")
    end

    def self.included(base)
      base.send :class_option, :interactive, type: :boolean, desc: "Show prompts. Default: true"
      base.send :class_option, :bundle, type: :boolean, desc: "Run bundle after setup. Default: true"
      base.send :class_option, :lint, type: :boolean, desc: "Run linter after generation. Default: false"

      base.include Concerns::PackageSelector
    end

    protected

    # ####################

    def prompt
      @prompt ||= TTY::Prompt.new
    end

    # def appname
    #   defined?(Rails.application) ? Rails.application.class.module_parent.name : "PlutoniumGenerators"
    # end

    # def app_name
    #   appname.underscore
    # end

    def pug_installed?(feature, version: nil)
      installed_version = read_config(:installed, feature)
      return false unless installed_version.present?

      version.present? ? SemanticRange.satisfies?(installed_version, ">=#{version}") : true
    end
  end
end
