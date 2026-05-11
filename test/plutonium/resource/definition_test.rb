# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::DefinitionTest < ActiveSupport::TestCase
  test "default modal is :slideover" do
    klass = Class.new(Plutonium::Resource::Definition)
    assert_equal :slideover, klass.modal_mode
  end

  test "modal :centered overrides default" do
    klass = Class.new(Plutonium::Resource::Definition) { modal :centered }
    assert_equal :centered, klass.modal_mode
  end

  test "modal :slideover is valid" do
    klass = Class.new(Plutonium::Resource::Definition) { modal :slideover }
    assert_equal :slideover, klass.modal_mode
  end

  test "modal :invalid raises ArgumentError" do
    assert_raises(ArgumentError) do
      Class.new(Plutonium::Resource::Definition) { modal :invalid }
    end
  end

  test "modal ArgumentError message is descriptive" do
    error = assert_raises(ArgumentError) do
      Class.new(Plutonium::Resource::Definition) { modal :fullscreen }
    end
    assert_match ":fullscreen", error.message
  end

  test "instance method #modal returns class-level setting" do
    klass = Class.new(Plutonium::Resource::Definition) { modal :centered }
    assert_equal :centered, klass.new.modal
  end

  test "instance method #modal returns default when not overridden" do
    klass = Class.new(Plutonium::Resource::Definition)
    assert_equal :slideover, klass.new.modal
  end

  test "subclass inherits parent modal mode" do
    parent = Class.new(Plutonium::Resource::Definition) { modal :centered }
    child = Class.new(parent)
    assert_equal :centered, child.modal_mode
  end

  test "subclass can override parent modal mode" do
    parent = Class.new(Plutonium::Resource::Definition) { modal :centered }
    child = Class.new(parent) { modal :slideover }
    assert_equal :slideover, child.modal_mode
    assert_equal :centered, parent.modal_mode
  end
end
