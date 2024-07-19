require "test_helper"

class PlutoniumTest < Minitest::Test
  def setup
    @original_env = ENV["PLUTONIUM_DEV"]
  end

  def teardown
    ENV["PLUTONIUM_DEV"] = @original_env
  end

  def test_root
    expected = Pathname.new(File.expand_path("..", __dir__))
    assert_equal expected, Plutonium.root
  end

  def test_lib_root
    expected = Plutonium.root.join("lib", "plutonium")
    assert_equal expected, Plutonium.lib_root
  end

  def test_logger
    assert_equal Rails.logger, Plutonium.logger
  end

  def test_application_name
    expected = Rails.application.class.module_parent_name
    refute_nil expected
    assert_equal expected, Plutonium.application_name
  end

  def test_application_name_assignment
    Plutonium.application_name = "TestApp"
    assert_equal "TestApp", Plutonium.application_name
  ensure
    Plutonium.application_name = nil
  end

  def test_development?
    ENV["PLUTONIUM_DEV"] = "true"
    assert Plutonium::Configuration.new.development?

    ENV["PLUTONIUM_DEV"] = "false"
    refute Plutonium::Configuration.new.development?
  end

  def test_eager_load_rails!
    Rails.env.stub(:production?, false) do
      Rails.application.stub(:eager_load!, true) do
        Rails.application.config.stub(:eager_load, false) do
          assert Plutonium.eager_load_rails!
        end
      end
    end
  end
end
