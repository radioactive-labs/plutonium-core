# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::SectionGridClassTest < Minitest::Test
  def grid(columns)
    form = Plutonium::UI::Form::Resource.allocate
    form.define_singleton_method(:themed) { |*| "THEMED_DEFAULT" }
    form.send(:section_grid_class, columns)
  end

  def test_nil_uses_themed_default
    assert_equal "THEMED_DEFAULT", grid(nil)
  end

  def test_one_column
    assert_equal "grid gap-6 grid-flow-row-dense grid-cols-1", grid(1)
  end

  def test_two_columns_adds_md
    assert_includes grid(2), "md:grid-cols-2"
  end

  def test_three_columns
    assert_includes grid(3), "lg:grid-cols-3"
  end

  def test_large_n
    assert_includes grid(6), "2xl:grid-cols-6"
  end
end
