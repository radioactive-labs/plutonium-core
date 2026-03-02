# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Page::BaseTest < ActiveSupport::TestCase
  test "page_content returns block when provided" do
    page = build_page
    custom_block = proc { "custom content" }

    result = page.send(:page_content, custom_block)

    assert_equal custom_block, result
  end

  test "page_content returns default content proc when no block" do
    page = build_page

    result = page.send(:page_content, nil)

    assert_kind_of Proc, result
  end

  test "page_content default proc raises NotImplementedError" do
    page = build_page
    default_proc = page.send(:page_content, nil)

    assert_raises(NotImplementedError) do
      default_proc.call
    end
  end

  test "view_template integrates with DynaFrameContent" do
    page = build_testable_page
    rendered_sections = []

    page.define_singleton_method(:render_before_header) { rendered_sections << :before_header }
    page.define_singleton_method(:render_header) { rendered_sections << :header }
    page.define_singleton_method(:render_after_header) { rendered_sections << :after_header }
    page.define_singleton_method(:render_before_content) { rendered_sections << :before_content }
    page.define_singleton_method(:render_after_content) { rendered_sections << :after_content }
    page.define_singleton_method(:render_before_footer) { rendered_sections << :before_footer }
    page.define_singleton_method(:render_footer) { rendered_sections << :footer }
    page.define_singleton_method(:render_after_footer) { rendered_sections << :after_footer }

    page.view_template { rendered_sections << :content }

    expected = [:before_header, :header, :after_header, :before_content, :content, :after_content, :before_footer, :footer, :after_footer]
    assert_equal expected, rendered_sections
  end

  test "view_template calls DynaFrameContent with page_content" do
    page = build_testable_page
    dyna_frame_called = false
    content_proc = nil

    page.define_singleton_method(:DynaFrameContent) do |content, &block|
      dyna_frame_called = true
      content_proc = content
      # Don't actually call the block - just verify DynaFrameContent was called
    end

    page.view_template { "test content" }

    assert dyna_frame_called, "DynaFrameContent should be called"
    assert_kind_of Proc, content_proc
  end

  private

  def build_page
    Plutonium::UI::Page::Base.new
  end

  def build_testable_page
    page = Plutonium::UI::Page::Base.new

    # Stub DynaFrameContent to simulate non-turbo-frame behavior
    page.define_singleton_method(:DynaFrameContent) do |content, &block|
      mock_frame = Object.new
      mock_frame.define_singleton_method(:render_content) { content&.call }
      block.call(mock_frame)
    end

    page
  end
end
