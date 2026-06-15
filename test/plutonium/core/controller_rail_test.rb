# frozen_string_literal: true

require "test_helper"

class Plutonium::Core::ControllerRailTest < ActiveSupport::TestCase
  def build_controller_class
    Class.new(ActionController::Base) { include Plutonium::Core::Controller }
  end

  def with_shell(value)
    original = Plutonium.configuration.shell
    Plutonium.configuration.shell = value
    yield
  ensure
    Plutonium.configuration.shell = original
  end

  test "rail? defaults to true for the modern shell" do
    with_shell(:modern) do
      assert build_controller_class.new.rail?
    end
  end

  test "rail? defaults to false for the plain shell" do
    with_shell(:plain) do
      refute build_controller_class.new.rail?
    end
  end

  test "rail? defaults to false for the classic shell" do
    with_shell(:classic) do
      refute build_controller_class.new.rail?
    end
  end

  test "rail false overrides the modern default" do
    klass = build_controller_class
    klass.rail false
    with_shell(:modern) do
      refute klass.new.rail?
    end
  end

  test "rail true overrides the plain default" do
    klass = build_controller_class
    klass.rail true
    with_shell(:plain) do
      assert klass.new.rail?
    end
  end

  test "rail setting inherits to subclasses" do
    parent = build_controller_class
    parent.rail false
    child = Class.new(parent)
    with_shell(:modern) do
      refute child.new.rail?
    end
  end

  test "subclass can override parent rail setting without affecting parent" do
    parent = build_controller_class
    parent.rail false
    child = Class.new(parent)
    child.rail true
    with_shell(:plain) do
      refute parent.new.rail?
      assert child.new.rail?
    end
  end

  test "rail? is registered as a helper method" do
    assert_includes build_controller_class._helper_methods, :rail?
  end

  test "rail? is callable as a public method" do
    assert_includes build_controller_class.new.public_methods, :rail?
  end

  test "shell falls back to the global config when nothing overrides it" do
    with_shell(:plain) do
      assert_equal :plain, build_controller_class.new.shell
    end
  end

  test "controller shell DSL overrides the global default" do
    klass = build_controller_class
    klass.shell :classic
    with_shell(:modern) do
      assert_equal :classic, klass.new.shell
    end
  end

  test "engine shell overrides the global default when the controller is unset" do
    engine = Class.new { def self.shell = :plain }
    controller = build_controller_class.new
    controller.define_singleton_method(:current_engine) { engine }
    with_shell(:modern) do
      assert_equal :plain, controller.shell
    end
  end

  test "controller shell overrides the engine shell" do
    engine = Class.new { def self.shell = :plain }
    klass = build_controller_class
    klass.shell :classic
    controller = klass.new
    controller.define_singleton_method(:current_engine) { engine }
    with_shell(:modern) do
      assert_equal :classic, controller.shell
    end
  end

  test "rail? follows the resolved shell" do
    klass = build_controller_class
    klass.shell :plain
    with_shell(:modern) do
      refute klass.new.rail?
    end
  end

  test "shell is registered as a helper method" do
    assert_includes build_controller_class._helper_methods, :shell
  end

  test "shell is callable as a public method" do
    assert_includes build_controller_class.new.public_methods, :shell
  end
end
