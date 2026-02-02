# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class LitestreamGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::MountsEngines

      desc "Set up Litestream for SQLite replication/backup"

      class_option :route, type: :string, default: "/manage/litestream",
        desc: "Route path for Litestream UI"
      class_option :credentials, type: :boolean, default: true,
        desc: "Configure Litestream to use Rails credentials"

      def start
        bundle "litestream"
        run_litestream_install
        create_litestream_script
        configure_kamal
        mount_litestream_engine
        configure_litestream_initializer
        show_instructions
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def run_litestream_install
        Bundler.with_unbundled_env do
          run "bin/rails generate litestream:install"
        end
        # Remove puma plugin added by litestream:install
        run "git checkout -- config/puma.rb 2>/dev/null || true"
      end

      def create_litestream_script
        litestream_script = "bin/litestream"
        return if File.exist?(File.expand_path(litestream_script, destination_root))

        create_file litestream_script, <<~BASH
          #!/usr/bin/env bash
          set -e
          exec bundle exec litestream replicate -config config/litestream.yml
        BASH
        chmod litestream_script, 0o755
      end

      def configure_kamal
        deploy_file = "config/deploy.yml"
        return unless File.exist?(File.expand_path(deploy_file, destination_root))
        return if file_includes?(deploy_file, "litestream:")

        insert_into_file deploy_file, after: /^servers:.*\n/ do
          <<~YAML
            litestream:
              hosts:
                - <%= ENV['DEPLOY_HOST'] %>
              cmd: bin/litestream
          YAML
        end
      end

      def mount_litestream_engine
        mount_engine %(mount Litestream::Engine, at: "#{options[:route]}"), authenticated: true
      end

      def configure_litestream_initializer
        return unless options[:credentials]

        initializer_file = "config/initializers/litestream.rb"
        uncomment_lines initializer_file, /litestream_credentials/
      end

      def show_instructions
        say ""
        say "Litestream Setup Instructions:", :green
        say "=" * 50
        say ""
        say "Litestream requires an S3-compatible storage provider (AWS S3, DigitalOcean Spaces, etc.)"
        say ""

        if options[:credentials]
          say "Edit your credentials to store bucket details:"
          say "  bin/rails credentials:edit"
          say ""
          say "Add the following:"
          say "  litestream:"
          say "    replica_bucket: <your-bucket-name>"
          say "    replica_key_id: <public-key>"
          say "    replica_access_key: <private-key>"
          say ""
          say "Verify configuration:"
          say "  bin/rails litestream:env"
        else
          say "Configure Litestream in: config/initializers/litestream.rb"
        end
        say ""
      end
    end
  end
end
