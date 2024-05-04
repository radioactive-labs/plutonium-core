# frozen_string_literal: true

require "rails/generators"
require File.expand_path("../plutonium_generators", __dir__)

module PlutoniumGenerators
  class CLI < Thor
    map "i" => :install
    map "g" => :generate
    map "ls" => :list
    map %w[--version -v] => :__print_version

    # desc "install", "Install Plutonium"
    # def install
    #   Rails::Generators.invoke("pu:install")
    # end

    desc "generate, g GENERATOR [options]", "Run plutonium generator"
    def generate(generator, *options)
      Rails::Generators.invoke("pu:#{generator}", options)
    end

    desc "list, ls", "View list of available generators"
    def list
      generators = Rails::Generators.sorted_groups.to_h["pu"]
      puts
      generators.each { |gen| puts gen.sub(/^pu:/, "") }
      puts
    end

    desc "--version, -v", "Print gem version"
    def __print_version
      puts "Plutonium generators #{PlutoniumGenerators::VERSION}"
    end

    class << self
      def exit_on_failure?
        true
      end
    end
  end
end
