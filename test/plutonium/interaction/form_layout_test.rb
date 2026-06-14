# frozen_string_literal: true

require "test_helper"

class Plutonium::Interaction::FormLayoutTest < Minitest::Test
  def test_interactions_get_the_form_layout_dsl
    klass = Class.new(Plutonium::Interaction::Base) do
      attribute :name
      form_layout { section :main, :name, label: "Main" }
    end
    assert_equal %i[main], klass.defined_form_layout.map(&:key)
    assert_respond_to klass.new(view_context: nil), :defined_form_layout
  end
end
