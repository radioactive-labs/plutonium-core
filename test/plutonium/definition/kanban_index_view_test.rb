# frozen_string_literal: true

require "test_helper"

class KanbanIndexViewTest < ActiveSupport::TestCase
  def def_class(&blk)
    Class.new(Plutonium::Resource::Definition) do
      class_eval(&blk) if blk
    end
  end

  test "declaring kanban enables the :kanban view alongside :table" do
    klass = def_class { kanban {} }
    assert_includes klass.defined_index_views, :kanban
    assert_includes klass.defined_index_views, :table
  end

  test "kanban stores the builder block" do
    klass = def_class { kanban {} }
    assert_kind_of Proc, klass.defined_kanban_block
  end

  test ":kanban is a known view" do
    assert_includes Plutonium::Definition::IndexViews::KNOWN_VIEWS, :kanban
  end
end
