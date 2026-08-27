# frozen_string_literal: true

require "test_helper"

class Plutonium::Wizard::WidthTest < Minitest::Test
  def wizard(&block)
    Class.new(Plutonium::Wizard::Base, &block)
  end

  def with_config(global: :md, wizards: :md)
    config = Plutonium.configuration
    previous_global = config.default_page_width
    previous_wizards = config.wizards.width
    config.default_page_width = global
    config.wizards.width = wizards
    yield
  ensure
    config.default_page_width = previous_global
    config.wizards.width = previous_wizards
  end

  def test_falls_back_to_the_wizards_config
    with_config(wizards: :lg) do
      assert_equal :lg, wizard {}.width
    end
  end

  # The whole point of a separate axis: moving resource pages must not move
  # wizards. `default_page_width` is not part of the wizard chain at all.
  def test_ignores_the_resource_default_page_width
    with_config(global: :xl, wizards: :sm) do
      assert_equal :sm, wizard {}.width,
        "a wizard must not follow config.default_page_width"
    end

    with_config(global: :full, wizards: :md) do
      assert_equal :md, wizard {}.width
    end
  end

  def test_per_wizard_width_wins_over_both
    with_config(global: :md, wizards: :lg) do
      assert_equal :sm, wizard { width :sm }.width
    end
  end

  # `:full` is a real choice, not "unset" — it must not fall through to the
  # configured defaults.
  def test_explicit_full_is_honoured
    with_config(global: :md, wizards: :lg) do
      klass = wizard { width :full }
      assert_equal :full, klass.width
      assert_nil Plutonium::UI::PageWidth.classes_for(klass.width)
    end
  end

  def test_unknown_width_raises_at_declaration
    error = assert_raises(ArgumentError) { wizard { width :enormous } }
    assert_match(/page width must be one of/, error.message)
  end

  def test_reader_does_not_clobber_the_setting
    with_config(wizards: :md) do
      klass = wizard { width :xl }
      klass.width # read once
      assert_equal :xl, klass.width, "reading must not reset the configured width"
    end
  end

  # A shared base class is the normal way to give a family of wizards one look
  # (`class IntakeWizard < Plutonium::Wizard::Base; width :xl; end`). Without
  # this the subclass silently fell back to the configured default.
  def test_width_is_inherited
    with_config(wizards: :md) do
      base = wizard { width :xl }
      assert_equal :xl, Class.new(base).width, "subclass inherits the declared width"
      assert_equal :xl, Class.new(Class.new(base)).width, "and down the chain"
    end
  end

  def test_subclass_can_override_the_inherited_width
    with_config(wizards: :md) do
      base = wizard { width :xl }
      sub = Class.new(base) { width :sm }
      assert_equal :sm, sub.width
      assert_equal :xl, base.width, "the subclass must not mutate its parent"
    end
  end
end
