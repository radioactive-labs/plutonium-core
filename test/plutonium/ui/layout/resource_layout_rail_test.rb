# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::ResourceLayoutRailTest < ActiveSupport::TestCase
  def build_layout(rail:, shell: :modern)
    layout = Plutonium::UI::Layout::ResourceLayout.allocate
    layout.define_singleton_method(:rail?) { rail }
    layout.define_singleton_method(:shell) { shell }
    layout
  end

  test "main_attributes includes lg:pl-20 for modern with rail" do
    classes = build_layout(rail: true, shell: :modern).send(:main_attributes)[:class]
    assert_includes classes, "lg:pl-20"
  end

  test "main_attributes drops the rail offset for modern without rail" do
    classes = build_layout(rail: false, shell: :modern).send(:main_attributes)[:class]
    refute_includes classes, "lg:pl-20"
  end

  test "main_attributes has no rail offset for the plain shell" do
    classes = build_layout(rail: false, shell: :plain).send(:main_attributes)[:class]
    refute_includes classes, "lg:pl-20"
    refute_includes classes, "lg:ml-64"
  end

  test "main_attributes keeps the classic sidebar offset" do
    classes = build_layout(rail: false, shell: :classic).send(:main_attributes)[:class]
    assert_includes classes, "lg:ml-64"
  end

  test "main_attributes includes lg:pl-20 for plain shell when rail is forced on" do
    classes = build_layout(rail: true, shell: :plain).send(:main_attributes)[:class]
    assert_includes classes, "lg:pl-20"
  end

  test "html_attributes adds pu-no-rail when rail-less (plain)" do
    attrs = build_layout(rail: false, shell: :plain).send(:html_attributes)
    assert_includes attrs[:class].to_s, "pu-no-rail"
  end

  test "html_attributes has no pu-no-rail when rail present" do
    attrs = build_layout(rail: true, shell: :modern).send(:html_attributes)
    refute_includes attrs[:class].to_s, "pu-no-rail"
  end

  test "html_attributes leaves classic shell untouched" do
    attrs = build_layout(rail: false, shell: :classic).send(:html_attributes)
    refute_includes attrs[:class].to_s, "pu-no-rail"
  end

  test "render_sidebar? is true for the classic shell even without a rail" do
    assert build_layout(rail: false, shell: :classic).send(:render_sidebar?)
  end

  test "render_sidebar? is true for modern with the rail active" do
    assert build_layout(rail: true, shell: :modern).send(:render_sidebar?)
  end

  test "render_sidebar? is false for a rail-less modern shell" do
    refute build_layout(rail: false, shell: :plain).send(:render_sidebar?)
  end
end
