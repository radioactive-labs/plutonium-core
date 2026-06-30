# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::KanbanIndexViewTest < Minitest::Test
  def def_class(&blk)
    Class.new(Plutonium::Resource::Definition) do
      class_eval(&blk) if blk
    end
  end

  def test_declaring_kanban_enables_the_kanban_view_alongside_table
    klass = def_class { kanban {} }
    assert_includes klass.defined_index_views, :kanban
    assert_includes klass.defined_index_views, :table
  end

  def test_kanban_stores_the_builder_block
    klass = def_class { kanban {} }
    assert_kind_of Proc, klass.defined_kanban_block
  end

  def test_kanban_is_a_known_view
    assert_includes Plutonium::Definition::IndexViews::KNOWN_VIEWS, :kanban
  end

  def test_calling_kanban_twice_does_not_duplicate_kanban_in_index_views
    klass = def_class do
      kanban {}
      kanban {}
    end
    assert_equal 1, klass.defined_index_views.count(:kanban)
  end
end
