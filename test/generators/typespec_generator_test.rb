# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/core/typespec/typespec_generator"

class TypespecGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Core::TypespecGenerator
  destination Rails.root

  def setup
    git_ensure_clean_dummy_app
  end

  test "generates typespec files for single portal" do
    run_generator ["--portal=admin_portal", "--output=tmp/typespec_test"]

    assert_file "tmp/typespec_test/common.tsp" do |content|
      assert_match(/scalar SignedGlobalId extends string/, content)
      assert_match(/model ResourceBase/, content)
      assert_match(/model ValidationError/, content)
      assert_match(/model ErrorResponse/, content)
      assert_match(/model PaginationMeta/, content)
      assert_match(/model ListQueryParams/, content)
    end

    assert_file "tmp/typespec_test/main.tsp" do |content|
      assert_match(/AdminPortal API/, content)
      assert_match(/import "\.\/common\.tsp"/, content)
      assert_match(/@service/, content)
      assert_match(/namespace AdminPortal/, content)
    end

    assert_directory "tmp/typespec_test/models"
  end

  test "generates typespec files for multiple portals" do
    run_generator ["--output=tmp/typespec_multi_test"]

    assert_file "tmp/typespec_multi_test/common.tsp"

    # Root main.tsp imports all portals
    assert_file "tmp/typespec_multi_test/main.tsp" do |content|
      assert_match(/import "\.\/common\.tsp"/, content)
    end
  end

  test "generates model files with correct structure" do
    run_generator ["--portal=admin_portal", "--output=tmp/typespec_model_test"]

    Dir["tmp/typespec_model_test/models/*.tsp"].each do |file|
      content = File.read(destination_root.join(file))

      # All model files should import common
      assert_match(/import "\.\.\/common\.tsp"/, content)

      # Should have response model extending ResourceBase
      assert_match(/model \w+ extends ResourceBase/, content)

      # Should have input model
      assert_match(/model \w+Input/, content)

      # Should have list response
      assert_match(/model \w+ListResponse/, content)

      # Should have operations interface
      assert_match(/interface \w+Operations/, content)

      # Should have CRUD operations
      assert_match(/@get\s+list/, content)
      assert_match(/@get\s+show/, content)
      assert_match(/@post\s+create/, content)
      assert_match(/@patch\s+update/, content)
      assert_match(/@delete\s+destroy/, content)
    end
  end

  test "custom output directory" do
    run_generator ["--portal=admin_portal", "--output=tmp/custom_typespec"]

    assert_directory "tmp/custom_typespec"
    assert_file "tmp/custom_typespec/common.tsp"
    assert_file "tmp/custom_typespec/main.tsp"
  end

  test "generates enum types for models with enums" do
    run_generator ["--portal=admin_portal", "--output=tmp/typespec_enum_test"]

    # OrganizationUser has enum :role
    org_user_file = Dir["tmp/typespec_enum_test/models/*organization_user*.tsp"].first
    skip "OrganizationUser model not found in portal" unless org_user_file

    content = File.read(destination_root.join(org_user_file))
    assert_match(/enum OrganizationUser\w*Role/, content)
    assert_match(/member/, content)
    assert_match(/owner/, content)
  end

  test "generates belongs_to associations with sgid fields" do
    run_generator ["--portal=admin_portal", "--output=tmp/typespec_assoc_test"]

    # OrganizationUser has belongs_to :organization and belongs_to :user
    org_user_file = Dir["tmp/typespec_assoc_test/models/*organization_user*.tsp"].first
    skip "OrganizationUser model not found in portal" unless org_user_file

    content = File.read(destination_root.join(org_user_file))

    # Should have foreign key and SGID for belongs_to associations
    assert_match(/organization_id\??:/, content)
    assert_match(/organization_sgid\??:\s*SignedGlobalId/, content)
    assert_match(/user_id\??:/, content)
    assert_match(/user_sgid\??:\s*SignedGlobalId/, content)
  end

  test "uses correct import path based on portal count" do
    # Single portal uses ./common.tsp
    run_generator ["--portal=admin_portal", "--output=tmp/typespec_single"]
    main_content = File.read(destination_root.join("tmp/typespec_single/main.tsp"))
    assert_match(/import "\.\/common\.tsp"/, main_content)

    model_files = Dir["tmp/typespec_single/models/*.tsp"]
    skip "No model files generated" if model_files.empty?
    model_content = File.read(destination_root.join(model_files.first))
    assert_match(/import "\.\.\/common\.tsp"/, model_content)
  end
end

class TypespecGeneratorUnitTest < ActiveSupport::TestCase
  def setup
    @generator = Pu::Core::TypespecGenerator.new
  end

  # TYPE_MAPPING tests
  test "TYPE_MAPPING covers common Rails column types" do
    mapping = Pu::Core::TypespecGenerator::TYPE_MAPPING

    assert_equal "string", mapping[:string]
    assert_equal "string", mapping[:text]
    assert_equal "int32", mapping[:integer]
    assert_equal "int64", mapping[:bigint]
    assert_equal "float64", mapping[:float]
    assert_equal "decimal", mapping[:decimal]
    assert_equal "boolean", mapping[:boolean]
    assert_equal "plainDate", mapping[:date]
    assert_equal "utcDateTime", mapping[:datetime]
    assert_equal "plainTime", mapping[:time]
    assert_equal "bytes", mapping[:binary]
    assert_equal "string", mapping[:uuid]
    assert_equal "Record<string, unknown>", mapping[:json]
    assert_equal "Record<string, unknown>", mapping[:jsonb]
    assert_equal "Record<string, string>", mapping[:hstore]
  end

  # AS_TYPE_MAPPING tests
  test "AS_TYPE_MAPPING covers form input types" do
    mapping = Pu::Core::TypespecGenerator::AS_TYPE_MAPPING

    assert_equal "string", mapping[:text]
    assert_equal "string", mapping[:textarea]
    assert_equal "string", mapping[:markdown]
    assert_equal "string", mapping[:rich_text]
    assert_equal "int32", mapping[:number]
    assert_equal "int32", mapping[:integer]
    assert_equal "decimal", mapping[:decimal]
    assert_equal "boolean", mapping[:boolean]
    assert_equal "boolean", mapping[:checkbox]
    assert_equal "plainDate", mapping[:date]
    assert_equal "utcDateTime", mapping[:datetime]
    assert_equal "plainTime", mapping[:time]
    assert_equal "bytes", mapping[:file]
    assert_equal "bytes", mapping[:attachment]
    assert_equal "string", mapping[:email]
    assert_equal "url", mapping[:url]
    assert_equal "string", mapping[:phone]
    assert_equal "string", mapping[:password]
    assert_equal "string", mapping[:color]
  end

  # column_to_typespec_type tests
  test "column_to_typespec_type returns int64 for nil column" do
    assert_equal "int64", @generator.send(:column_to_typespec_type, nil)
  end

  test "column_to_typespec_type maps integer types correctly" do
    skip "User model not available" unless defined?(User) && User.table_exists?

    user_columns = User.columns
    id_column = user_columns.find { |c| c.name == "id" }
    skip "id column not found" unless id_column

    result = @generator.send(:column_to_typespec_type, id_column)
    assert_includes %w[int32 int64 string], result
  end

  test "column_to_typespec_type falls back to int64 for unknown types" do
    # Create a mock column with an unknown type
    mock_column = Struct.new(:type).new(:unknown_type)
    assert_equal "int64", @generator.send(:column_to_typespec_type, mock_column)
  end

  # safe_constantize tests
  test "safe_constantize returns nil for invalid class names" do
    assert_nil @generator.send(:safe_constantize, "NonExistentClass::ThatDoesNotExist")
  end

  test "safe_constantize returns class for valid names" do
    assert_equal User, @generator.send(:safe_constantize, "User") if defined?(User)
    assert_equal String, @generator.send(:safe_constantize, "String")
  end

  # build_columns_data tests
  test "build_columns_data returns column metadata" do
    skip "User model not available" unless defined?(User) && User.table_exists?

    columns = @generator.send(:build_columns_data, User)

    assert_kind_of Array, columns
    assert columns.any?, "Should have at least one column"

    first_col = columns.first
    assert first_col.key?(:name)
    assert first_col.key?(:type)
    assert first_col.key?(:null)
    assert first_col.key?(:typespec_type)
  end

  test "build_columns_data maps types using TYPE_MAPPING" do
    skip "User model not available" unless defined?(User) && User.table_exists?

    columns = @generator.send(:build_columns_data, User)
    string_col = columns.find { |c| c[:type] == "string" }

    if string_col
      assert_equal "string", string_col[:typespec_type]
    end
  end

  # build_associations_data tests
  test "build_associations_data returns association metadata" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser) && OrganizationUser.table_exists?

    associations = @generator.send(:build_associations_data, OrganizationUser)

    assert_kind_of Array, associations
    assert associations.any?, "OrganizationUser should have associations"

    org_assoc = associations.find { |a| a[:name] == "organization" }
    assert org_assoc, "Should have organization association"
    assert_equal "belongs_to", org_assoc[:macro]
    assert_equal false, org_assoc[:polymorphic]
  end

  test "build_associations_data includes foreign key type" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser) && OrganizationUser.table_exists?

    associations = @generator.send(:build_associations_data, OrganizationUser)
    org_assoc = associations.find { |a| a[:name] == "organization" }

    assert org_assoc[:foreign_key_type], "Should have foreign_key_type"
    assert_includes %w[int32 int64 string], org_assoc[:foreign_key_type]
  end

  # build_enums_data tests
  test "build_enums_data returns enum values" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser)

    enums = @generator.send(:build_enums_data, OrganizationUser)

    assert_kind_of Hash, enums
    assert enums.key?("role"), "OrganizationUser should have role enum"
    assert_includes enums["role"], "member"
    assert_includes enums["role"], "owner"
  end

  test "build_enums_data returns empty hash for models without enums" do
    skip "User model not available" unless defined?(User)

    enums = @generator.send(:build_enums_data, User)
    # User may or may not have enums, but should return a hash
    assert_kind_of Hash, enums
  end

  # resolve_foreign_key_type tests
  test "resolve_foreign_key_type returns int64 for polymorphic associations" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser)

    # Create a mock polymorphic association
    mock_assoc = Struct.new(:polymorphic?, :macro).new(true, :belongs_to)
    result = @generator.send(:resolve_foreign_key_type, mock_assoc, OrganizationUser)
    assert_equal "int64", result
  end

  test "resolve_foreign_key_type looks up target class for belongs_to" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser) && OrganizationUser.table_exists?

    org_assoc = OrganizationUser.reflect_on_association(:organization)
    skip "organization association not found" unless org_assoc

    result = @generator.send(:resolve_foreign_key_type, org_assoc, OrganizationUser)
    assert_includes %w[int32 int64 string], result
  end

  # primary_key_type tests
  test "primary_key_type returns correct type for model" do
    skip "User model not available" unless defined?(User) && User.table_exists?

    result = @generator.send(:primary_key_type, User)
    assert_includes %w[int32 int64 string], result
  end

  # safe_association_attr tests
  test "safe_association_attr returns attribute value" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser)

    org_assoc = OrganizationUser.reflect_on_association(:organization)
    skip "organization association not found" unless org_assoc

    result = @generator.send(:safe_association_attr, org_assoc, :foreign_key)
    assert_equal "organization_id", result
  end

  test "safe_association_attr returns nil for invalid attributes" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser)

    org_assoc = OrganizationUser.reflect_on_association(:organization)
    skip "organization association not found" unless org_assoc

    # Mock an association that raises NameError
    mock_assoc = Object.new
    def mock_assoc.klass
      raise NameError, "uninitialized constant"
    end

    result = @generator.send(:safe_association_attr, mock_assoc, :klass)
    assert_nil result
  end

  # determine_input_type tests
  test "determine_input_type returns as option when present" do
    config = {as: :markdown}
    result = @generator.send(:determine_input_type, :content, config, nil, nil, User)
    assert_equal "markdown", result
  end

  test "determine_input_type returns association for association fields" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser)

    config = {}
    assoc = OrganizationUser.reflect_on_association(:organization)
    result = @generator.send(:determine_input_type, :organization, config, nil, assoc, OrganizationUser)
    assert_equal "association", result
  end

  test "determine_input_type returns enum for enum fields" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser)

    config = {}
    result = @generator.send(:determine_input_type, :role, config, nil, nil, OrganizationUser)
    assert_equal "enum", result
  end

  test "determine_input_type returns column type when available" do
    skip "User model not available" unless defined?(User) && User.table_exists?

    config = {}
    column = User.columns_hash["email"]
    skip "email column not found" unless column

    result = @generator.send(:determine_input_type, :email, config, column, nil, User)
    assert_equal column.type.to_s, result
  end

  test "determine_input_type defaults to string" do
    config = {}
    result = @generator.send(:determine_input_type, :unknown, config, nil, nil, User)
    assert_equal "string", result
  end

  # determine_typespec_input_type tests
  test "determine_typespec_input_type returns SignedGlobalId for belongs_to" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser)

    config = {}
    assoc = OrganizationUser.reflect_on_association(:organization)
    result = @generator.send(:determine_typespec_input_type, :organization, config, nil, assoc, OrganizationUser)
    assert_equal "SignedGlobalId", result
  end

  test "determine_typespec_input_type returns SignedGlobalId array for has_many" do
    # Create a mock has_many association
    mock_assoc = Struct.new(:macro).new(:has_many)
    config = {}

    result = @generator.send(:determine_typespec_input_type, :items, config, nil, mock_assoc, User)
    assert_equal "SignedGlobalId[]", result
  end

  test "determine_typespec_input_type returns enum type name for enums" do
    skip "OrganizationUser model not available" unless defined?(OrganizationUser)

    config = {}
    result = @generator.send(:determine_typespec_input_type, :role, config, nil, nil, OrganizationUser)
    assert_equal "OrganizationUserRole", result
  end

  test "determine_typespec_input_type uses column type mapping" do
    skip "User model not available" unless defined?(User) && User.table_exists?

    config = {}
    column = User.columns_hash["created_at"]
    skip "created_at column not found" unless column

    result = @generator.send(:determine_typespec_input_type, :created_at, config, column, nil, User)
    assert_equal "utcDateTime", result
  end

  test "determine_typespec_input_type uses AS_TYPE_MAPPING for as option" do
    config = {as: :email}
    result = @generator.send(:determine_typespec_input_type, :contact_email, config, nil, nil, User)
    assert_equal "string", result
  end

  test "determine_typespec_input_type defaults to string" do
    config = {}
    result = @generator.send(:determine_typespec_input_type, :unknown, config, nil, nil, User)
    assert_equal "string", result
  end
end
