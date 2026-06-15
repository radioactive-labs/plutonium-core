# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::ResourceLayoutRailTest < ActiveSupport::TestCase
  def build_layout(rail:)
    layout = Plutonium::UI::Layout::ResourceLayout.allocate
    layout.define_singleton_method(:rail?) { rail }
    layout
  end

  def with_shell(value)
    original = Plutonium.configuration.shell
    Plutonium.configuration.shell = value
    yield
  ensure
    Plutonium.configuration.shell = original
  end

  test "main_attributes includes lg:pl-20 for modern with rail" do
    with_shell(:modern) do
      classes = build_layout(rail: true).send(:main_attributes)[:class]
      assert_includes classes, "lg:pl-20"
    end
  end

  test "main_attributes drops the rail offset for modern without rail" do
    with_shell(:modern) do
      classes = build_layout(rail: false).send(:main_attributes)[:class]
      refute_includes classes, "lg:pl-20"
    end
  end

  test "main_attributes has no rail offset for the plain shell" do
    with_shell(:plain) do
      classes = build_layout(rail: false).send(:main_attributes)[:class]
      refute_includes classes, "lg:pl-20"
      refute_includes classes, "lg:ml-64"
    end
  end

  test "main_attributes keeps the classic sidebar offset" do
    with_shell(:classic) do
      classes = build_layout(rail: false).send(:main_attributes)[:class]
      assert_includes classes, "lg:ml-64"
    end
  end

  test "html_attributes adds pu-no-rail when rail-less (plain)" do
    with_shell(:plain) do
      attrs = build_layout(rail: false).send(:html_attributes)
      assert_includes attrs[:class].to_s, "pu-no-rail"
    end
  end

  test "html_attributes has no pu-no-rail when rail present" do
    with_shell(:modern) do
      attrs = build_layout(rail: true).send(:html_attributes)
      refute_includes attrs[:class].to_s, "pu-no-rail"
    end
  end

  test "html_attributes leaves classic shell untouched" do
    with_shell(:classic) do
      attrs = build_layout(rail: false).send(:html_attributes)
      refute_includes attrs[:class].to_s, "pu-no-rail"
    end
  end

  test "main_attributes includes lg:pl-20 for plain shell when rail is forced on" do
    with_shell(:plain) do
      classes = build_layout(rail: true).send(:main_attributes)[:class]
      assert_includes classes, "lg:pl-20"
    end
  end
end
