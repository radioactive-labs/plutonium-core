# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "rails/generators"
require "generators/pu/docker/install/install_generator"

# The Dockerfiles used to hardcode Node 22.2 + yarn 1.22 and
# `COPY package.json yarn.lock`, which cannot build a bun app (no yarn.lock)
# or a yarn 2+ app (yarn 1 cannot read its lockfile). They now branch on the
# package manager jsbundling-rails will pick inside the image.
class DockerInstallGeneratorTest < ActiveSupport::TestCase
  def setup
    @dir = Dir.mktmpdir("pu-docker")
    File.write(File.join(@dir, ".ruby-version"), "3.3.6\n")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  test "yarn 1 app installs yarn through npm and copies yarn.lock" do
    dockerfile = render("Dockerfile", lockfile: "yarn.lock", yarn: "1.22.22")

    assert_includes dockerfile, "ARG NODE_VERSION=22.23.2"
    assert_includes dockerfile, "ARG YARN_VERSION=1.22.22"
    assert_includes dockerfile, "npm install -g yarn@$YARN_VERSION"
    assert_includes dockerfile, "COPY package.json yarn.lock .yarnrc.yml* ./"
    assert_includes dockerfile, "RUN yarn install --frozen-lockfile"
    refute_includes dockerfile, "corepack"
    refute_includes dockerfile, "bun install"
  end

  test "yarn 2+ app installs yarn through corepack and uses --immutable" do
    dockerfile = render("Dockerfile", lockfile: "yarn.lock", yarn: "4.9.2")

    assert_includes dockerfile, "ARG YARN_VERSION=4.9.2"
    assert_includes dockerfile, "corepack enable && corepack install -g yarn@$YARN_VERSION"
    assert_includes dockerfile, "RUN yarn install --immutable"
    refute_includes dockerfile, "npm install -g yarn"
    refute_includes dockerfile, "frozen-lockfile"
  end

  test "bun app installs bun instead of node and copies bun.lock" do
    dockerfile = render("Dockerfile", lockfile: "bun.lock")

    assert_includes dockerfile, "ARG BUN_VERSION=1.3.11"
    assert_includes dockerfile, "https://bun.sh/install"
    assert_includes dockerfile, "COPY package.json bun.lock* ./"
    assert_includes dockerfile, "RUN bun install --frozen-lockfile"
    refute_includes dockerfile, "node-build"
    refute_includes dockerfile, "yarn"
  end

  test "npm app uses npm ci" do
    dockerfile = render("Dockerfile", lockfile: "package-lock.json")

    assert_includes dockerfile, "COPY package.json package-lock.json ./"
    assert_includes dockerfile, "RUN npm ci"
    refute_includes dockerfile, "yarn"
  end

  test "Dockerfile.dev installs the same toolchain" do
    assert_includes render("Dockerfile.dev", lockfile: "bun.lock"), "https://bun.sh/install"
    assert_includes render("Dockerfile.dev", lockfile: "yarn.lock", yarn: "4.9.2"), "corepack install -g yarn@$YARN_VERSION"
  end

  test "docker-compose runs the matching install before bin/dev" do
    assert_includes render("docker-compose.yml", lockfile: "bun.lock"), "bundle && bun install && bin/dev"
    assert_includes render("docker-compose.yml", lockfile: "yarn.lock"), "bundle && yarn install && bin/dev"
  end

  test "falls back to pinned versions when the tool is not on PATH" do
    dockerfile = render("Dockerfile", lockfile: "yarn.lock", node: nil, yarn: nil)

    assert_includes dockerfile, "ARG NODE_VERSION=#{Pu::Docker::InstallGenerator::NODE_LTS_VERSION}"
    assert_includes dockerfile, "ARG YARN_VERSION=#{Pu::Docker::InstallGenerator::YARN_CLASSIC_VERSION}"
  end

  private

  def render(name, lockfile:, node: "22.23.2", yarn: "1.22.22", bun: "1.3.11")
    FileUtils.rm_f(Dir.glob(File.join(@dir, "{*.lock,*.lockb,*.yaml,*.json}")))
    FileUtils.touch(File.join(@dir, lockfile))

    generator = Pu::Docker::InstallGenerator.new([], {}, destination_root: @dir)
    generator.define_singleton_method(:node_version) { node }
    generator.define_singleton_method(:yarn_version) { yarn }
    generator.define_singleton_method(:bun_version) { bun }
    generator.define_singleton_method(:js_package_manager) { PlutoniumGenerators::Concerns::JsPackageManager::LOCKFILES.find { |_, files| files.include?(lockfile) }.first }

    capture_io { generator.template(name, name, force: true) }
    File.read(File.join(@dir, name))
  end
end
