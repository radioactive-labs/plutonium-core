# frozen_string_literal: true

begin
  # jsbundling-rails `main` ships the detector its build task uses (unreleased
  # as of 1.3.1).
  require "jsbundling/package_manager"
rescue LoadError
  # Older jsbundling-rails, or an app without it: fall back to the same rules.
end

module PlutoniumGenerators
  module Concerns
    # Detects the host app's JavaScript package manager and builds the matching
    # shell commands, so generators never hardcode `yarn`.
    #
    # Detection follows what `rails javascript:build` consults at precompile
    # time. Installing with the same tool keeps a single lockfile: the lockfile
    # decides, and with no lockfile the first executable on PATH among bun,
    # yarn, pnpm and npm wins (yarn when none is found). `rails new -j esbuild`
    # therefore yields a bun app on any machine that has bun installed, and
    # this concern follows it rather than adding a yarn.lock next to bun.lock.
    # When the app's jsbundling-rails provides Jsbundling::PackageManager, that
    # detector is used as is (it skips yarn.lock and decides by PATH).
    #
    # Yarn 1 (classic) and Yarn 2+ (berry) share `add` but differ elsewhere;
    # `yarn_berry?` distinguishes them by asking the yarn the app resolves to.
    module JsPackageManager
      ADD_COMMANDS = {
        bun: "bun add %s",
        pnpm: "pnpm add %s",
        npm: "npm install %s",
        yarn: "yarn add %s"
      }.freeze

      INSTALL_COMMANDS = {
        bun: "bun install",
        pnpm: "pnpm install",
        npm: "npm ci",
        yarn: "yarn install"
      }.freeze

      RUN_COMMANDS = {
        bun: "bun run %s",
        pnpm: "pnpm run %s",
        npm: "npm run %s",
        yarn: "yarn %s"
      }.freeze

      LOCKFILES = {
        bun: %w[bun.lock bun.lockb],
        pnpm: %w[pnpm-lock.yaml],
        npm: %w[package-lock.json],
        yarn: %w[yarn.lock]
      }.freeze

      protected

      # @return [Symbol] one of :bun, :pnpm, :npm, :yarn
      def js_package_manager
        @js_package_manager ||= detect_js_package_manager
      end

      # One command that adds every package. `pkg@latest` and `pkg@^1.2.3`
      # are understood identically by all four managers, which is why callers
      # pass versions inline instead of running a separate upgrade step
      # (yarn 1 `upgrade --latest` has no yarn 2+ equivalent).
      def js_add_command(*packages)
        format(ADD_COMMANDS.fetch(js_package_manager), packages.flatten.join(" "))
      end

      def js_install_command
        INSTALL_COMMANDS.fetch(js_package_manager)
      end

      def js_run_command(script)
        format(RUN_COMMANDS.fetch(js_package_manager), script)
      end

      # Yarn 2+ ("berry"). Asks the yarn the app resolves to, so corepack and
      # a `packageManager` field are honoured.
      def yarn_berry?
        js_package_manager == :yarn && yarn_version.to_i >= 2
      end

      def yarn_version
        @yarn_version ||= capture_tool_version("yarn --version")
      end

      def bun_version
        @bun_version ||= capture_tool_version("bun --version")
      end

      def node_version
        @node_version ||= capture_tool_version("node --version")
      end

      # Yarn 2+ defaults to Plug'n'Play, which Tailwind's PostCSS plugin cannot
      # be loaded under (postcss-load-config's require() options are not
      # supported by PnP). Pin the node-modules linker, which is what the rest
      # of the Rails toolchain expects, unless the app already chose a linker.
      def ensure_yarn_node_modules_linker
        return unless yarn_berry?

        yarnrc = ".yarnrc.yml"
        existing = in_root_dir { File.exist?(yarnrc) ? File.read(yarnrc) : nil }

        if existing.nil?
          create_file yarnrc, "nodeLinker: node-modules\n"
        elsif existing.match?(/^nodeLinker:/)
          unless existing.match?(/^nodeLinker:\s*node-modules\b/)
            warn "#{yarnrc} sets a nodeLinker other than node-modules; the Tailwind PostCSS plugin does not load under Plug'n'Play"
          end
        else
          append_to_file yarnrc, "nodeLinker: node-modules\n"
        end
      end

      private

      def detect_js_package_manager
        root = Pathname(destination_root)
        return Jsbundling::PackageManager.detect(root) if defined?(Jsbundling::PackageManager)

        LOCKFILES.each do |manager, files|
          return manager if files.any? { |f| root.join(f).exist? }
        end
        return :bun if root.join("bun.config.js").exist?

        %i[bun yarn pnpm npm].find { |exe| system("command -v #{exe} > /dev/null") } || :yarn
      end

      def capture_tool_version(command)
        output = in_root_dir { `#{command} 2>/dev/null` }
        output[/\d+\.\d+\.\d+/]
      rescue SystemCallError
        nil
      end

      # Thor's in_root returns the block value too, but only once the generator
      # has a destination stack; this stays usable from plain unit tests.
      def in_root_dir(&)
        Dir.chdir(destination_root, &)
      end
    end
  end
end
