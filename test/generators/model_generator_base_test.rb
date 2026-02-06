# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "generators/pu/lib/plutonium_generators"

class ModelGeneratorBaseTest < ActiveSupport::TestCase
  GeneratedAttribute = PlutoniumGenerators::ModelGeneratorBase::GeneratedAttribute

  # Default value parsing tests

  test "parses default value for string type" do
    attr = GeneratedAttribute.parse("Post", "status:string{default:draft}")

    assert_equal "status", attr.name
    assert_equal :string, attr.type
    assert_equal "draft", attr.attr_options[:default]
    assert_equal false, attr.attr_options[:null]
  end

  test "parses default value for integer type with coercion" do
    attr = GeneratedAttribute.parse("Post", "count:integer{default:0}")

    assert_equal "count", attr.name
    assert_equal :integer, attr.type
    assert_equal 0, attr.attr_options[:default]
  end

  test "parses default value for float type with coercion" do
    attr = GeneratedAttribute.parse("Post", "rating:float{default:4.5}")

    assert_equal "rating", attr.name
    assert_equal :float, attr.type
    assert_equal 4.5, attr.attr_options[:default]
  end

  test "parses default value for decimal type with coercion" do
    attr = GeneratedAttribute.parse("Post", "price:decimal{default:9.99}")

    assert_equal "price", attr.name
    assert_equal :decimal, attr.type
    assert_equal 9.99, attr.attr_options[:default]
  end

  test "parses default value true for boolean type" do
    attr = GeneratedAttribute.parse("Post", "active:boolean{default:true}")

    assert_equal "active", attr.name
    assert_equal :boolean, attr.type
    assert_equal true, attr.attr_options[:default]
  end

  test "parses default value false for boolean type" do
    attr = GeneratedAttribute.parse("Post", "archived:boolean{default:false}")

    assert_equal "archived", attr.name
    assert_equal :boolean, attr.type
    assert_equal false, attr.attr_options[:default]
  end

  test "parses default value yes for boolean type" do
    attr = GeneratedAttribute.parse("Post", "published:boolean{default:yes}")

    assert_equal true, attr.attr_options[:default]
  end

  test "parses default value 1 for boolean type" do
    attr = GeneratedAttribute.parse("Post", "featured:boolean{default:1}")

    assert_equal true, attr.attr_options[:default]
  end

  test "parses default value with nullable type" do
    attr = GeneratedAttribute.parse("Post", "status:string?{default:pending}")

    assert_equal "status", attr.name
    assert_equal :string, attr.type
    assert_equal "pending", attr.attr_options[:default]
    assert_equal true, attr.attr_options[:null]
  end

  test "parses default value combined with decimal precision" do
    attr = GeneratedAttribute.parse("Post", "amount:decimal{10,2,default:0.00}")

    assert_equal "amount", attr.name
    assert_equal :decimal, attr.type
    assert_equal 0.0, attr.attr_options[:default]
    assert_equal 10, attr.attr_options[:precision]
    assert_equal 2, attr.attr_options[:scale]
  end

  test "parses default value at end of options" do
    # Note: default value should come after precision/scale options
    # Syntax: decimal{precision,scale,default:value}
    attr = GeneratedAttribute.parse("Post", "price:decimal{10,2,default:99.99}")

    assert_equal 99.99, attr.attr_options[:default]
    assert_equal 10, attr.attr_options[:precision]
    assert_equal 2, attr.attr_options[:scale]
  end

  test "parses nullable with default value and precision" do
    attr = GeneratedAttribute.parse("Post", "balance:decimal?{15,2,default:0}")

    assert_equal true, attr.attr_options[:null]
    assert_equal 0.0, attr.attr_options[:default]
    assert_equal 15, attr.attr_options[:precision]
    assert_equal 2, attr.attr_options[:scale]
  end

  # Nullable type tests

  test "parses nullable string type" do
    attr = GeneratedAttribute.parse("Post", "subtitle:string?")

    assert_equal "subtitle", attr.name
    assert_equal :string, attr.type
    assert_equal true, attr.attr_options[:null]
  end

  test "parses required string type" do
    attr = GeneratedAttribute.parse("Post", "title:string")

    assert_equal "title", attr.name
    assert_equal :string, attr.type
    assert_equal false, attr.attr_options[:null]
  end

  test "required? returns false for nullable fields" do
    attr = GeneratedAttribute.parse("Post", "description:text?")

    refute attr.required?
  end

  test "required? returns false for non-nullable fields without default required behavior" do
    # Note: required? in Rails GeneratedAttribute checks for specific conditions
    # Our override only considers null: true as not required
    attr = GeneratedAttribute.parse("Post", "title:string")

    # The base Rails implementation determines required? based on type
    # String fields are not required by default in the generator
    refute attr.required?
  end

  # Cents field tests

  test "cents? returns true for _cents integer fields" do
    attr = GeneratedAttribute.parse("Post", "price_cents:integer")

    assert attr.cents?
  end

  test "cents? returns false for non-cents fields" do
    attr = GeneratedAttribute.parse("Post", "count:integer")

    refute attr.cents?
  end

  test "attribute_name strips _cents suffix for cents fields" do
    attr = GeneratedAttribute.parse("Post", "price_cents:integer")

    assert_equal "price", attr.attribute_name
  end

  test "attribute_name returns name for non-cents fields" do
    attr = GeneratedAttribute.parse("Post", "count:integer")

    assert_equal "count", attr.attribute_name
  end

  # Cross-package reference tests

  test "parses cross-package belongs_to reference" do
    attr = GeneratedAttribute.parse("Comment", "blogging/post:belongs_to")

    assert_equal "blogging_post", attr.name
    assert_equal :belongs_to, attr.type
    assert_equal :blogging_posts, attr.attr_options[:to_table]
    assert_equal "Blogging::Post", attr.attr_options[:class_name]
  end

  test "parses cross-package reference with shared namespace" do
    attr = GeneratedAttribute.parse("blogging/comment", "blogging/post:belongs_to")

    # When model and reference share namespace, the shared part is stripped
    assert_equal "post", attr.name
    assert_equal :belongs_to, attr.type
  end

  # class_name option tests

  test "parses belongs_to with class_name option" do
    attr = GeneratedAttribute.parse("Post", "author:belongs_to{class_name:User}")

    assert_equal "author", attr.name
    assert_equal :belongs_to, attr.type
    assert_equal "User", attr.attr_options[:class_name]
    assert_equal :users, attr.attr_options[:to_table]
  end

  test "parses nullable belongs_to with class_name option" do
    attr = GeneratedAttribute.parse("Post", "reviewer:belongs_to?{class_name:User}")

    assert_equal "reviewer", attr.name
    assert_equal :belongs_to, attr.type
    assert_equal "User", attr.attr_options[:class_name]
    assert_equal :users, attr.attr_options[:to_table]
    assert_equal true, attr.attr_options[:null]
  end

  test "parses belongs_to with namespaced class_name" do
    attr = GeneratedAttribute.parse("Post", "author:belongs_to{class_name:Admin::User}")

    assert_equal "author", attr.name
    assert_equal :belongs_to, attr.type
    assert_equal "Admin::User", attr.attr_options[:class_name]
    assert_equal :admin_users, attr.attr_options[:to_table]
  end

  test "options_for_migration includes foreign_key with to_table for class_name" do
    attr = GeneratedAttribute.parse("Post", "author:belongs_to{class_name:User}")

    migration_options = attr.options_for_migration
    assert_equal({to_table: :users}, migration_options[:foreign_key])
    refute migration_options.key?(:class_name)
    refute migration_options.key?(:to_table)
  end

  # Index type tests

  test "parses field with index" do
    attr = GeneratedAttribute.parse("Post", "slug:string:index")

    assert_equal "slug", attr.name
    assert_equal :string, attr.type
    assert attr.has_index?
  end

  test "parses field with unique index" do
    attr = GeneratedAttribute.parse("Post", "email:string:uniq")

    assert_equal "email", attr.name
    assert_equal :string, attr.type
    assert attr.has_uniq_index?
  end
end
