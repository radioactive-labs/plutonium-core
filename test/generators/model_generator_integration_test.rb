# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/res/model/model_generator"

class ModelGeneratorIntegrationTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Res::ModelGenerator
  destination Rails.root

  def setup
    git_ensure_clean_dummy_app
  end

  # Note: --migration flag is needed for Rails::Generators::TestCase
  # (CLI sets this automatically but test harness doesn't)

  test "generates migration with string default value" do
    run_generator ["TestModel", "status:string{default:draft}", "--dest=main_app", "--migration"]

    migration_file = find_migration("create_test_models")
    assert migration_file, "Migration file should exist"

    content = File.read(migration_file)
    assert_match(/t\.string :status.*default: "draft"/, content)
  end

  test "generates migration with integer default value" do
    run_generator ["TestModel", "priority:integer{default:0}", "--dest=main_app", "--migration"]

    migration_file = find_migration("create_test_models")
    assert migration_file, "Migration file should exist"

    content = File.read(migration_file)
    assert_match(/t\.integer :priority.*default: 0/, content)
  end

  test "generates migration with boolean default value" do
    run_generator ["TestModel", "active:boolean{default:true}", "--dest=main_app", "--migration"]

    migration_file = find_migration("create_test_models")
    assert migration_file, "Migration file should exist"

    content = File.read(migration_file)
    assert_match(/t\.boolean :active.*default: true/, content)
  end

  test "generates migration with empty hash default for jsonb" do
    run_generator ["TestModel", "metadata:jsonb{default:{}}", "--dest=main_app", "--migration"]

    migration_file = find_migration("create_test_models")
    assert migration_file, "Migration file should exist"

    content = File.read(migration_file)
    assert_match(/t\.jsonb :metadata.*default: \{\}/, content)
  end

  test "generates migration with empty array default for jsonb" do
    run_generator ["TestModel", "tags:jsonb{default:[]}", "--dest=main_app", "--migration"]

    migration_file = find_migration("create_test_models")
    assert migration_file, "Migration file should exist"

    content = File.read(migration_file)
    assert_match(/t\.jsonb :tags.*default: \[\]/, content)
  end

  test "generates migration with object default for jsonb" do
    run_generator ["TestModel", 'settings:jsonb{default:{"theme":"dark"}}', "--dest=main_app", "--migration"]

    migration_file = find_migration("create_test_models")
    assert migration_file, "Migration file should exist"

    content = File.read(migration_file)
    # The hash will be serialized, check for the key at minimum
    assert_match(/t\.jsonb :settings.*default:.*theme/, content)
  end

  test "generates migration with nullable field and default" do
    run_generator ["TestModel", "category:string?{default:general}", "--dest=main_app", "--migration"]

    migration_file = find_migration("create_test_models")
    assert migration_file, "Migration file should exist"

    content = File.read(migration_file)
    assert_match(/t\.string :category.*null: true.*default: "general"/, content)
  end

  test "generates migration with decimal precision and default" do
    run_generator ["TestModel", "price:decimal{10,2,default:0}", "--dest=main_app", "--migration"]

    migration_file = find_migration("create_test_models")
    assert migration_file, "Migration file should exist"

    content = File.read(migration_file)
    assert_match(/t\.decimal :price.*precision: 10.*scale: 2.*default: 0/, content)
  end

  private

  def find_migration(name)
    Dir.glob(destination_root.join("db/migrate/*_#{name}.rb")).first
  end
end
