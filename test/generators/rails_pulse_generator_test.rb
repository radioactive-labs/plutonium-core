# frozen_string_literal: true


require "test_helper"
require "rails/generators"
require "generators/pu/lite/rails_pulse/rails_pulse_generator"

class RailsPulseGeneratorTest < ActiveSupport::TestCase
  test "rails_pulse generator exists and has correct namespace" do
    assert defined?(Pu::Lite::RailsPulseGenerator)
    assert Pu::Lite::RailsPulseGenerator < Rails::Generators::Base
  end

  test "rails_pulse generator includes PlutoniumGenerators::Generator" do
    assert Pu::Lite::RailsPulseGenerator.include?(PlutoniumGenerators::Generator)
  end

  test "rails_pulse generator includes ConfiguresSqlite and MountsEngines concerns" do
    assert Pu::Lite::RailsPulseGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
    assert Pu::Lite::RailsPulseGenerator.include?(PlutoniumGenerators::Concerns::MountsEngines)
  end

  test "rails_pulse generator has database option defaulting to 'rails_pulse'" do
    options = Pu::Lite::RailsPulseGenerator.class_options
    assert options.key?(:database)
    assert_equal "rails_pulse", options[:database].default
  end

  test "rails_pulse generator has route option with default '/manage/pulse'" do
    options = Pu::Lite::RailsPulseGenerator.class_options
    assert options.key?(:route)
    assert_equal "/manage/pulse", options[:route].default
  end

  test "rails_pulse generator has source_root set" do
    assert Pu::Lite::RailsPulseGenerator.source_root.present?
    assert File.directory?(Pu::Lite::RailsPulseGenerator.source_root)
  end
end

class RailsPulseTemplateTest < ActiveSupport::TestCase
  TEMPLATE_PATH = File.expand_path(
    "../../lib/generators/pu/lite/rails_pulse/templates/config/initializers/rails_pulse.rb.tt",
    __dir__
  )

  def setup
    @template_content = File.read(TEMPLATE_PATH)
  end

  test "template exists" do
    assert File.exist?(TEMPLATE_PATH)
  end

  test "template includes RailsPulse.configure block" do
    assert_match(/RailsPulse\.configure do \|config\|/, @template_content)
  end

  test "template includes enabled configuration" do
    assert_match(/config\.enabled/, @template_content)
  end

  test "template includes track_assets configuration" do
    assert_match(/config\.track_assets/, @template_content)
  end

  test "template has conditional database configuration" do
    assert_match(/if options\[:database\]/, @template_content)
    assert_match(/config\.connects_to/, @template_content)
  end
end

class RailsPulseRecurringInjectionTest < ActiveSupport::TestCase
  def setup
    @generator = Pu::Lite::RailsPulseGenerator.allocate
  end

  test "rails_pulse_tasks_yaml pads every non-empty line by the requested indent" do
    yaml = @generator.send(:rails_pulse_tasks_yaml, 2)

    yaml.each_line do |line|
      next if line.strip.empty?
      assert_match(/\A {2}/, line, "expected line to start with 2-space pad: #{line.inspect}")
    end
  end

  test "rails_pulse_tasks_yaml leaves blank lines unindented" do
    yaml = @generator.send(:rails_pulse_tasks_yaml, 4)
    blanks = yaml.lines.select { |l| l.strip.empty? }

    assert blanks.any?, "expected at least one blank line separator"
    blanks.each { |l| assert_equal "\n", l }
  end

  test "rails_pulse_tasks_yaml uses human schedule strings" do
    yaml = @generator.send(:rails_pulse_tasks_yaml, 0)

    assert_match(/schedule: every hour at minute 5/, yaml)
    assert_match(/schedule: every day at 1am/, yaml)
    assert_match(/queue: default/, yaml)
  end

  test "inject_rails_pulse_under_envs adds entries inside each env block" do
    content = <<~YAML
      production:
        existing_job:
          class: Foo
          schedule: every hour

      development:
        dev_job:
          class: Bar
          schedule: every day at 9am
    YAML

    result = @generator.send(:inject_rails_pulse_under_envs, content, %w[production development staging test])

    parsed = YAML.safe_load(result)
    assert_equal %w[dev_job rails_pulse_cleanup rails_pulse_summary],
      parsed["development"].keys.sort
    assert_equal %w[existing_job rails_pulse_cleanup rails_pulse_summary],
      parsed["production"].keys.sort
    assert_equal "RailsPulse::SummaryJob", parsed["production"]["rails_pulse_summary"]["class"]
    assert_equal "RailsPulse::CleanupJob", parsed["development"]["rails_pulse_cleanup"]["class"]
  end

  test "inject_rails_pulse_under_envs preserves existing entries verbatim" do
    content = <<~YAML
      production:
        existing_job:
          class: Foo
          schedule: every hour
    YAML

    result = @generator.send(:inject_rails_pulse_under_envs, content, %w[production development staging test])

    assert_includes result, "existing_job:\n    class: Foo\n    schedule: every hour"
  end

  test "inject_rails_pulse_under_envs respects nonstandard indent" do
    content = "production:\n    deep:\n        class: Foo\n        schedule: every hour\n"

    result = @generator.send(:inject_rails_pulse_under_envs, content, %w[production development staging test])

    assert_match(/^    rails_pulse_summary:/, result)
    assert_match(/^      class: RailsPulse::SummaryJob/, result)
    parsed = YAML.safe_load(result)
    assert_equal "RailsPulse::SummaryJob", parsed["production"]["rails_pulse_summary"]["class"]
  end

  test "inject_rails_pulse_under_envs only touches recognized env keys" do
    content = <<~YAML
      production:
        job:
          class: Foo
          schedule: every hour

      shared_anchors:
        something:
          class: Bar
          schedule: every hour
    YAML

    result = @generator.send(:inject_rails_pulse_under_envs, content, %w[production development staging test])
    parsed = YAML.safe_load(result)

    assert_includes parsed["production"].keys, "rails_pulse_summary"
    refute_includes parsed["shared_anchors"].keys, "rails_pulse_summary"
  end
end
