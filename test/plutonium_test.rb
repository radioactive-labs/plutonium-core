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
    # Reset the eager loaded flag for testing
    Plutonium.instance_variable_set(:@rails_eager_loaded, nil)

    # Store original value and temporarily set eager_load to false
    original_eager_load = Rails.application.config.eager_load
    Rails.application.config.eager_load = false

    # The method should return truthy (sets @rails_eager_loaded = true)
    # In test environment, eager_load! is already done, so we just verify the flag gets set
    Plutonium.eager_load_rails!
    assert Plutonium.instance_variable_get(:@rails_eager_loaded)
  ensure
    Rails.application.config.eager_load = original_eager_load
    Plutonium.instance_variable_set(:@rails_eager_loaded, nil)
  end
end
