# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    module ConfiguresRecurring
      ENV_KEYS = %w[production development staging test].freeze

      # Pure transform of a config/recurring.yml string. No file IO — testable
      # in isolation, mirroring ConfiguresSqlite::DatabaseYAML.
      class RecurringYAML
        # Returns new content with `tasks_yaml` injected. If the file is
        # env-scoped (has top-level production:/development:/... keys), the
        # tasks are inserted under each environment at the siblings' indent.
        # Otherwise they are appended at column 0.
        def inject(content, tasks_yaml)
          if env_scoped?(content)
            inject_under_envs(content, tasks_yaml)
          else
            content.rstrip + "\n\n" + indent(tasks_yaml, 0)
          end
        end

        private

        def env_scoped?(content)
          content.lines.any? { |l| l.match?(env_re) }
        end

        def env_re
          /^(#{ENV_KEYS.join("|")}):\s*$/
        end

        def indent(yaml, n)
          pad = " " * n
          yaml.gsub(/^(?=.)/, pad)
        end

        def inject_under_envs(content, tasks_yaml)
          lines = content.lines
          env_starts = lines.each_with_index.select { |l, _| env_re.match?(l) }.map(&:last)

          env_starts.reverse_each do |start|
            end_idx = lines.length
            ((start + 1)...lines.length).each do |i|
              if lines[i].match?(/^[^\s#]/)
                end_idx = i
                break
              end
            end

            child_indent = 2
            ((start + 1)...end_idx).each do |i|
              if (m = lines[i].match(/^(\s+)\S/))
                child_indent = m[1].length
                break
              end
            end

            insert_at = end_idx
            while insert_at > start + 1 && lines[insert_at - 1].strip.empty?
              insert_at -= 1
            end

            lines.insert(insert_at, "\n", indent(tasks_yaml, child_indent))
          end

          lines.join
        end
      end

      private

      # Inject recurring task YAML into config/recurring.yml. Returns true when
      # written, false when the file is missing or the marker already present
      # (idempotent). `marker` is matched with file_includes? to avoid dupes.
      def add_recurring_tasks(tasks_yaml, marker:)
        recurring_file = "config/recurring.yml"
        full_path = File.expand_path(recurring_file, destination_root)
        return false unless File.exist?(full_path)
        return false if file_includes?(recurring_file, marker)

        new_content = RecurringYAML.new.inject(File.read(full_path), tasks_yaml)
        create_file recurring_file, new_content, force: true
        say_status :recurring, "#{marker} (config/recurring.yml)"
        true
      end
    end
  end
end
