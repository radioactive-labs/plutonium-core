# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class TuneGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Tune config/database.yml with performance pragmas for SQLite"

      RAILS_8_1 = ::Gem::Version.new("8.1.0")
      DATABASE_YML = "config/database.yml"

      def start
        path = File.expand_path(DATABASE_YML, destination_root)
        unless File.exist?(path)
          log :skip, "#{DATABASE_YML} not found"
          return
        end

        content = File.read(path)
        if content.include?("wal_autocheckpoint")
          log :skip, "pragmas already tuned in #{DATABASE_YML}"
          return
        end

        new_content = apply_pragmas(content, rails_version)
        if new_content == content
          log :skip, "no `default: &default` block in #{DATABASE_YML}"
          return
        end

        create_file DATABASE_YML, new_content, force: true
        say_status :tune, "added SQLite pragmas to #{DATABASE_YML}"
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      # Pure: returns content with pragmas inserted into the `default: &default`
      # block. Merges into an existing default-level `pragmas:` mapping (2-space
      # indent) if present, otherwise inserts a fresh pragmas block. Returns the
      # content unchanged when there is no default anchor. Scoped to the default
      # block so a `pragmas:` nested under another env (e.g. production.primary)
      # is never touched.
      def apply_pragmas(content, version)
        anchor = content.match(/^default: &default\n/)
        return content unless anchor

        body_start = anchor.end(0)
        rest = content[body_start..]
        # the default block runs until the next top-level (column-0) line
        next_top = rest =~ /^\S/
        default_body = next_top ? rest[0...next_top] : rest
        tail = next_top ? rest[next_top..] : ""

        if default_body.match?(/^  pragmas:\s*$/)
          new_body = default_body.sub(/^(  pragmas:[ \t]*\n)/) { $1 + pragma_keys(version) }
          content[0...body_start] + new_body + tail
        else
          content.sub(/^default: &default\n/, "default: &default\n" + pragma_block(version))
        end
      end

      def pragma_block(version)
        comment = <<~COMMENT.gsub(/^/, "  ")
          # Plutonium-tuned SQLite pragmas (pu:lite:tune).
          # Rails 8.1+ already sets WAL, synchronous=NORMAL, foreign_keys,
          # mmap=128MB and journal_size_limit by default; only deltas are added
          # there. We intentionally do NOT set SQLite's internal busy pragma —
          # Rails routes the `timeout:` key to the sqlite3 gem's constant-poll
          # busy_handler_timeout, which has better tail-latency than SQLite's
          # backoff.
          pragmas:
        COMMENT
        comment + pragma_keys(version)
      end

      def pragma_keys(version)
        keys = +""
        if version < RAILS_8_1
          keys << <<~YAML.gsub(/^/, "    ")
            journal_mode: WAL
            synchronous: NORMAL
            foreign_keys: true
            journal_size_limit: 67108864 # 64 MB
          YAML
        end
        keys << <<~YAML.gsub(/^/, "    ")
          cache_size: -64000           # 64 MB page cache (default ~2 MB is too small)
          temp_store: 2                # MEMORY — sorts/temp indexes stay off disk
          mmap_size: 536870912         # 512 MB (override the 128 MB default)
          wal_autocheckpoint: 10000    # checkpoint every ~40 MB of WAL, fewer pauses
        YAML
        keys
      end

      def rails_version
        @rails_version ||= ::Gem::Version.new(Rails::VERSION::STRING).release
      end
    end
  end
end
