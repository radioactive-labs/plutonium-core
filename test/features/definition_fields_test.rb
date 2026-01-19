# frozen_string_literal: true

require "test_helper"

class DefinitionFieldsTest < Minitest::Test
  # Test that field, input, display, column declarations work as documented

  def test_field_declaration_at_class_level
    definition_class = Class.new(Plutonium::Resource::Definition) do
      field :title, as: :string
      field :content, as: :markdown
      field :status, as: :select, choices: %w[draft published]
    end

    assert_equal 3, definition_class.defined_fields.size
    assert definition_class.defined_fields.key?(:title)
    assert definition_class.defined_fields.key?(:content)
    assert definition_class.defined_fields.key?(:status)

    assert_equal :string, definition_class.defined_fields[:title][:options][:as]
    assert_equal :markdown, definition_class.defined_fields[:content][:options][:as]
    assert_equal :select, definition_class.defined_fields[:status][:options][:as]
  end

  def test_input_declaration
    definition_class = Class.new(Plutonium::Resource::Definition) do
      input :email, as: :email, hint: "Enter your email"
      input :password, as: :password, required: true
    end

    assert_equal 2, definition_class.defined_inputs.size
    assert_equal :email, definition_class.defined_inputs[:email][:options][:as]
    assert_equal "Enter your email", definition_class.defined_inputs[:email][:options][:hint]
    assert_equal :password, definition_class.defined_inputs[:password][:options][:as]
  end

  def test_display_declaration
    definition_class = Class.new(Plutonium::Resource::Definition) do
      display :content, as: :markdown
      display :status, wrapper: {class: "col-span-full"}
    end

    assert_equal 2, definition_class.defined_displays.size
    assert_equal :markdown, definition_class.defined_displays[:content][:options][:as]
    assert_equal({class: "col-span-full"}, definition_class.defined_displays[:status][:options][:wrapper])
  end

  def test_column_declaration
    definition_class = Class.new(Plutonium::Resource::Definition) do
      column :title, align: :start
      column :status, align: :center
      column :amount, align: :end
    end

    assert_equal 3, definition_class.defined_columns.size
    assert_equal :start, definition_class.defined_columns[:title][:options][:align]
    assert_equal :center, definition_class.defined_columns[:status][:options][:align]
    assert_equal :end, definition_class.defined_columns[:amount][:options][:align]
  end

  def test_field_with_block
    definition_class = Class.new(Plutonium::Resource::Definition) do
      field :custom do |f|
        # Block for custom rendering
      end
    end

    assert definition_class.defined_fields[:custom][:block]
  end

  def test_definition_inheritance
    parent_class = Class.new(Plutonium::Resource::Definition) do
      field :name, as: :string
      input :email, as: :email
    end

    child_class = Class.new(parent_class) do
      field :age, as: :integer
      input :phone, as: :tel
    end

    # Child should have both parent and own fields
    child_instance = child_class.new
    assert child_instance.defined_fields.key?(:name)
    assert child_instance.defined_fields.key?(:age)
    assert child_instance.defined_inputs.key?(:email)
    assert child_instance.defined_inputs.key?(:phone)
  end

  def test_instance_level_customization
    definition_class = Class.new(Plutonium::Resource::Definition) do
      field :title, as: :string

      def customize_fields
        field :dynamic_field, as: :text
      end
    end

    instance = definition_class.new
    assert instance.defined_fields.key?(:title)
    assert instance.defined_fields.key?(:dynamic_field)
  end

  def test_condition_option
    definition_class = Class.new(Plutonium::Resource::Definition) do
      display :published_at, condition: -> { object.published? }
    end

    assert definition_class.defined_displays[:published_at][:options][:condition]
    assert definition_class.defined_displays[:published_at][:options][:condition].is_a?(Proc)
  end

  def test_blogging_post_definition_fields
    # Test that our tutorial definition has the expected field customization
    assert Blogging::PostDefinition.defined_fields.key?(:body)
    assert_equal :text, Blogging::PostDefinition.defined_fields[:body][:options][:as]

    # Test column customizations
    assert Blogging::PostDefinition.defined_columns.key?(:user)
    assert_equal "Author", Blogging::PostDefinition.defined_columns[:user][:options][:label]

    # Test computed column
    assert Blogging::PostDefinition.defined_columns.key?(:comment_count)

    # Test page titles
    assert_equal "Blog Posts", Blogging::PostDefinition.index_page_title
    assert_equal "Manage your blog content", Blogging::PostDefinition.index_page_description
  end
end
