# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Display::SecretFieldRenderTest < ActiveSupport::TestCase
  test "a secret column never reaches the show page markup" do
    html = Plutonium::UI::Display::Base.new(KitchenSink.new(secret: "hunter2")).field(:secret).component_for(nil).call

    refute_includes html, "hunter2"
    assert_includes html, "••••••••"
  end

  test "a secret column never reaches a table cell" do
    field = Plutonium::UI::Table::Base::Display.new(KitchenSink.new(secret: "hunter2")).field(:secret)

    refute_includes field.component_for(nil).call, "hunter2"
  end

  test "as: :secret masks like as: :password on the show page" do
    html = Plutonium::UI::Display::Base.new(KitchenSink.new(name: "hunter2")).field(:name).component_for(:secret).call

    refute_includes html, "hunter2"
    assert_includes html, "••••••••"
  end

  test "as: :secret renders the masking input on a form" do
    html = Plutonium::UI::Form::Base.new(KitchenSink.new(name: "hunter2")).field(:name).component_for(:secret).call

    refute_includes html, "hunter2"
    assert_includes html, 'type="password"'
  end
end
