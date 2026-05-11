# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Page::BaseTest < ActiveSupport::TestCase
  test "view_template invokes lifecycle hooks in order" do
    page = build_testable_page
    rendered = []

    page.define_singleton_method(:render_before_header) { rendered << :before_header }
    page.define_singleton_method(:render_header) { rendered << :header }
    page.define_singleton_method(:render_after_header) { rendered << :after_header }
    page.define_singleton_method(:render_before_content) { rendered << :before_content }
    page.define_singleton_method(:render_after_content) { rendered << :after_content }
    page.define_singleton_method(:render_before_footer) { rendered << :before_footer }
    page.define_singleton_method(:render_footer) { rendered << :footer }
    page.define_singleton_method(:render_after_footer) { rendered << :after_footer }

    page.view_template { rendered << :content }

    expected = [:before_header, :header, :after_header, :before_content, :content, :after_content, :before_footer, :footer, :after_footer]
    assert_equal expected, rendered
  end

  test "view_template falls back to render_default_content when no block" do
    page = build_testable_page
    called = false
    page.define_singleton_method(:render_default_content) { called = true }
    page.define_singleton_method(:render_header) { nil }
    page.define_singleton_method(:render_footer) { nil }

    page.view_template

    assert called, "render_default_content should be invoked when no block is given"
  end

  test "render_default_content raises NotImplementedError on Base" do
    page = Plutonium::UI::Page::Base.new

    assert_raises(NotImplementedError) do
      page.send(:render_default_content)
    end
  end

  private

  def build_testable_page
    page = Plutonium::UI::Page::Base.new
    # Stub DynaFrameContent so it just yields the block without calling
    # any Rails view context.
    page.define_singleton_method(:DynaFrameContent) do |&block|
      block&.call
    end
    page
  end
end
