# frozen_string_literal: true

require_relative "../lib/plutonium_generators"

module Pu
  # Scaffolds a dashboard class and mounts it in a portal (or the main app).
  #
  #   rails g pu:dashboard Sales --dest=admin_portal
  #   rails g pu:dashboard Home --dest=admin_portal --at=/     # the portal root
  #
  # Writes `app/dashboards/<portal>/<name>_dashboard.rb` inside the package
  # and adds `register_dashboard` to its routes. A root mount replaces the
  # generated `root to: "dashboard#index"` line.
  class DashboardGenerator < Rails::Generators::NamedBase
    include PlutoniumGenerators::Generator

    source_root File.expand_path("templates", __dir__)

    desc(
      "Create a dashboard and mount it in a portal\n\n" \
      "e.g. rails g pu:dashboard Sales --dest=admin_portal\n" \
      "     rails g pu:dashboard Home --dest=admin_portal --at=/"
    )

    class_option :at, type: :string, default: nil,
      desc: "Mount path inside the portal (default: the dashboard name; \"/\" mounts at the root)"

    def start
      @app_namespace = portal_option(:dest, prompt: "Select destination portal").camelize

      template "dashboard.rb", dashboard_file_path
      register_dashboard_in_routes
    rescue => e
      exception "#{self.class} failed:", e
    end

    private

    attr_reader :app_namespace

    def main_app? = app_namespace == "MainApp"

    def package_namespace = app_namespace.underscore

    def dashboard_name = "#{class_name.delete_suffix("Dashboard")}Dashboard"

    def dashboard_class_name
      main_app? ? dashboard_name : "#{app_namespace}::#{dashboard_name}"
    end

    def dashboard_label = dashboard_name.delete_suffix("Dashboard").titleize

    def mount_path
      path = options[:at].presence || dashboard_name.delete_suffix("Dashboard").underscore
      path.to_s.sub(%r{\A/+}, "").sub(%r{/+\z}, "")
    end

    def root_mount? = mount_path.empty?

    def dashboard_file_path
      file = "#{dashboard_name.underscore}.rb"
      main_app? ? "app/dashboards/#{file}" : "packages/#{package_namespace}/app/dashboards/#{package_namespace}/#{file}"
    end

    def routes_path
      main_app? ? "config/routes.rb" : "packages/#{package_namespace}/config/routes.rb"
    end

    def register_line
      constant = main_app? ? "::#{dashboard_class_name}" : dashboard_class_name
      %(register_dashboard #{constant}, at: "#{root_mount? ? "/" : mount_path}")
    end

    # Idempotent: skips when the routes already register this dashboard. A root
    # mount replaces the portal's generated `root to:` line, since two roots
    # would clash.
    def register_dashboard_in_routes
      content = File.read(File.join(destination_root, routes_path))

      if /^\s*register_dashboard #{Regexp.escape("::" + dashboard_class_name)}\b|^\s*register_dashboard #{Regexp.escape(dashboard_class_name)}\b/.match?(content)
        say_status :identical, "#{routes_path} already registers #{dashboard_class_name}", :blue
        return
      end

      if root_mount? && (match = content.match(/^\s*root to: "dashboard#index".*\n/))
        gsub_file routes_path, match[0], indent("#{register_line}\n", 2)
      elsif /^\s*#\s*register resources above\b/.match?(content)
        insert_into_file routes_path, indent("#{register_line}\n", 2), before: /^\s*#\s*register resources above\b.*/
      elsif (match = content.match(/^\s*(\w+::Engine|Rails\.application)\.routes\.draw do.*\n/))
        insert_into_file routes_path, indent("#{register_line}\n", 2), after: match[0]
      else
        say_status :warn, "Could not locate routes block in #{routes_path}; add manually: #{register_line}", :yellow
      end
    end
  end
end
