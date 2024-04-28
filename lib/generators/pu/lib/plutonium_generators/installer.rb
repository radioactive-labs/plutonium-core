# frozen_string_literal: true

require "semantic_range"
require "yaml"

module PlutoniumGenerators
  module Installer
    def self.included(base)
      base.send :source_root, File.expand_path("lib/generators/pu/setup/_templates", PlutoniumGenerators::ROOT_DIR)

      base.send :class_option, :interactive, type: :boolean, desc: "Show prompts. Default: true"
      base.send :class_option, :bundle, type: :boolean, desc: "Run bundle after setup. Default: true"
      base.send :class_option, :lint, type: :boolean, desc: "Run linter after generation. Default: false"
      base.send :class_option, :pug_id, type: :numeric, default: 0,
        desc: "Used internally by plutonium generators. " \
         "Do not set this value as it might lead to unspecified behaviour."
      base.send :class_option, :force, type: :boolean, default: false,
        desc: "Force installation even if it have been previously installed."
    end

    protected

    def install!(feature)
      set_ruby_version! if root_pug?

      from_version = read_config(:installed, feature, default: "0.0.0")
      versions = methods.map do |m|
        m.to_s.match(/install_v([\d_]+)/)&.[](1)&.tr("_", ".")
      end
      versions = versions.select do |version|
        force? || SemanticRange.satisfies?(version, ">#{from_version}")
      end.compact.sort

      if versions.any?
        versions.each do |version|
          log :install!, "#{feature} v#{version}"
          send :"install_v#{version.tr(".", "_")}!"
        end

        installed_version = versions.last
        write_config :installed, feature => installed_version

        if root_pug?
          if bundle?
            bundle!
            # run last minute bundle changes
            bundle! false
          end

          begin
            log :rubocop, "autocorrect"
            run_eval "bundle exec standardrb --fix"
          rescue
            # Do nothing
          end

          success "Successfully installed #{feature} v#{installed_version}"
        end
      else
        debug "Skipping installation of #{feature}. No new versions since v#{from_version}."
      end
    rescue => e
      exception "#{self.class.desc} failed:", e
    end

    def add_gem(name, **)
      log :add_gem, name
      before_bundle(:gem, name, **)
    end

    def rubocop(library = nil)
      log :rubocop, "install #{library}"

      add_gem "rubocop", group: :development, require: false

      in_root do
        rubocop_file = ".rubocop.yml"
        if File.exist?(rubocop_file)
          rubocop_def = YAML.load_file(rubocop_file)
          rubocop_def["require"] ||= []
        else
          rubocop_def = {
            "require" => [],
            "Style/FrozenStringLiteralComment" => {"SafeAutoCorrect" => true},
            "Style/ClassAndModuleChildren" => {"SafeAutoCorrect" => true}
          }
        end

        if library.present?
          library = "rubocop-#{library}"
          add_gem library, group: :development, require: false
          rubocop_def["require"] << library
        end

        rubocop_def["require"].uniq!
        create_file rubocop_file, YAML.dump(rubocop_def), force: true, verbose: false
      end
    end

    def after_bundle(command, *args, **kwargs)
      add_task_after(:bundle, [command, args, kwargs])
    end

    def before_bundle(command, *args, **kwargs)
      add_task_before(:bundle, [command, args, kwargs])
    end

    def yes?(statement, color = nil)
      !interactive? || super(statement, color)
    end

    def interactive?
      options[:interactive] != false
    end

    def bundle?
      options[:bundle] != false
    end

    def lint?
      options[:lint] == true
    end

    def pug(command)
      args = options.slice("lint", "interactive").map { |k, v| "--#{k} #{v}" }.join " "
      generate "pu:#{command} --pug-id=#{depth + 1} --force=#{force?} #{args}"
    end

    private

    def bundle!(run_tasks = true)
      log :bundle, "install"

      execute_tasks_before! :bundle if run_tasks
      Bundler.with_unbundled_env do
        run "bundle install", verbose: false
      end
      execute_tasks_after! :bundle if run_tasks
    end

    def add_task(event, action, task)
      log :add_task, "#{event} #{action}: #{task}"

      key = :"tasks_#{event}"
      tasks = read_config(key, action, default: [])
      tasks << task
      write_config(key, action => tasks)
    end

    def execute_tasks!(event, action)
      log :execute_tasks!, "#{event} #{action}"

      key = :"tasks_#{event}"
      tasks = read_config(key, action, default: [])
      tasks.each do |a|
        task = a[0]
        args = a[1] || []
        kwargs = a[2] || {}

        log :execute_task, "#{event} #{action}: #{task}"
        send task, *args, **kwargs
      end

      write_config(key, action => [])
    end

    def add_task_before(action, task)
      add_task :before, action, task
    end

    def add_task_after(action, task)
      add_task :after, action, task
    end

    def execute_tasks_before!(action)
      execute_tasks! :before, action
    end

    def execute_tasks_after!(action)
      execute_tasks! :after, action
    end

    def depth
      options[:pug_id]
    end

    def force?
      options[:force]
    end

    def root_pug?
      depth == 0
    end

    # def process(cmd)
    #   stdout, stderr, status = Open3.capture3(cmd + ";")
    #   case status.exitstatus
    #   when 0
    #     stdout
    #   else
    #     raise stderr
    #   end
    # end
  end
end
