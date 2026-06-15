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
end
