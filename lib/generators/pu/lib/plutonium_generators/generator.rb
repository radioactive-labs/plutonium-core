# frozen_string_literal: true

require "semantic_range"
require "tty-prompt"

module PlutoniumGenerators
  module Generator
    include Concerns::Config
    include Concerns::Logger
    include Concerns::Serializer
    include Concerns::Actions

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
