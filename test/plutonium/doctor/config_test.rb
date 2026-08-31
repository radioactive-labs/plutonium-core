# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Plutonium::Doctor::ConfigTest < Minitest::Test
  Config = Plutonium::Doctor::Config

  def test_no_file_disables_nothing
    with_config(nil) do |config|
      refute config.disabled?(:redundant_field_declaration)
      assert_nil config.path
    end
  end

  def test_reads_disabled_checks
    with_config(<<~YAML) do |config|
      disable:
        - redundant_field_declaration
    YAML
      assert config.disabled?(:redundant_field_declaration)
      refute config.disabled?(:missing_policy_rule)
    end
  end

  def test_disabled_accepts_a_string_or_a_symbol
    with_config("disable:\n  - missing_policy_rule\n") do |config|
      assert config.disabled?(:missing_policy_rule)
      assert config.disabled?("missing_policy_rule")
    end
  end

  def test_ignores_a_finding_by_the_key_the_report_prints
    with_config(<<~YAML) do |config|
      ignore:
        - missing_policy_rule:Blogging::Post#publish
    YAML
      assert config.ignored?(finding("Blogging::Post#publish"))
      refute config.ignored?(finding("Blogging::Post#archive"))
    end
  end

  def test_an_empty_file_is_not_an_error
    with_config("") do |config|
      refute config.disabled?(:missing_policy_rule)
    end
  end

  def test_records_the_path_it_read_so_the_report_can_name_it
    with_config("disable: []\n") do |config|
      assert_equal ".plutonium-doctor.yml", File.basename(config.path)
    end
  end

  private

  def finding(subject)
    Plutonium::Doctor::Finding.new(
      check: :missing_policy_rule,
      severity: :error,
      subject: subject,
      message: "x"
    )
  end

  def with_config(contents)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, Config::DEFAULT_FILENAME), contents) if contents
      yield Config.load(root: dir)
    end
  end
end
