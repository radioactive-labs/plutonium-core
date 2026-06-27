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

  test "instance method #modal_mode returns class-level setting" do
    klass = Class.new(Plutonium::Resource::Definition) { modal :centered }
    assert_equal :centered, klass.new.modal_mode
  end

  # show_in — how the show page opens (independent of modal_mode)

  test "default show_in is :page" do
    klass = Class.new(Plutonium::Resource::Definition)
    assert_equal :page, klass.show_in
    assert_equal :page, klass.new.show_in
  end

  test "show_in :modal overrides default" do
    klass = Class.new(Plutonium::Resource::Definition) { show_in :modal }
    assert_equal :modal, klass.show_in
  end

  test "show_in :invalid raises a descriptive ArgumentError" do
    error = assert_raises(ArgumentError) do
      Class.new(Plutonium::Resource::Definition) { show_in :sidebar }
    end
    assert_match(/show_in must be one of/, error.message)
    assert_match(":sidebar", error.message)
  end

  test "subclass inherits parent show_in" do
    parent = Class.new(Plutonium::Resource::Definition) { show_in :modal }
    child = Class.new(parent)
    assert_equal :modal, child.show_in
  end

  test "instance method #modal_mode returns default when not overridden" do
    klass = Class.new(Plutonium::Resource::Definition)
    assert_equal :slideover, klass.new.modal_mode
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

  test "default modal_size is :md" do
    klass = Class.new(Plutonium::Resource::Definition)
    assert_equal :md, klass.modal_size
  end

  test "modal size: stores on the class" do
    klass = Class.new(Plutonium::Resource::Definition) { modal :centered, size: :lg }
    assert_equal :lg, klass.modal_size
  end

  test "modal size: :invalid raises ArgumentError" do
    error = assert_raises(ArgumentError) do
      Class.new(Plutonium::Resource::Definition) { modal :centered, size: :huge }
    end
    assert_match(/modal size must be one of/, error.message)
    assert_match(":huge", error.message)
  end
end
