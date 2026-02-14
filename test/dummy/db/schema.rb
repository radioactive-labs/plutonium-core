# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_09_044032) do
  create_table "admin_active_session_keys", primary_key: ["admin_id", "session_id"], force: :cascade do |t|
    t.integer "admin_id"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "last_use", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "session_id"
    t.index ["admin_id"], name: "index_admin_active_session_keys_on_admin_id"
  end

  create_table "admin_authentication_audit_logs", force: :cascade do |t|
    t.integer "admin_id", null: false
    t.datetime "at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "message", null: false
    t.json "metadata"
    t.index ["admin_id", "at"], name: "audit_admin_admin_id_at_idx"
    t.index ["admin_id"], name: "index_admin_authentication_audit_logs_on_admin_id"
    t.index ["at"], name: "audit_admin_at_idx"
  end

  create_table "admin_lockouts", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent"
    t.string "key", null: false
  end

  create_table "admin_login_failures", force: :cascade do |t|
    t.integer "number", default: 1, null: false
  end

  create_table "admin_otp_keys", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "last_use", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "num_failures", default: 0, null: false
  end

  create_table "admin_password_reset_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
  end

  create_table "admin_recovery_codes", primary_key: ["id", "code"], force: :cascade do |t|
    t.string "code"
    t.bigint "id"
  end

  create_table "admin_remember_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
  end

  create_table "admin_verification_keys", force: :cascade do |t|
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "admins", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_hash"
    t.integer "status", default: 1, null: false
    t.index ["email"], name: "index_admins_on_email", unique: true, where: "status IN (1, 2)"
  end

  create_table "blogging_comments", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["post_id"], name: "index_blogging_comments_on_post_id"
    t.index ["user_id"], name: "index_blogging_comments_on_user_id"
  end

  create_table "blogging_post_metadata", force: :cascade do |t|
    t.string "canonical_url"
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.text "seo_description"
    t.string "seo_title"
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_blogging_post_metadata_on_post_id"
  end

  create_table "blogging_posts", force: :cascade do |t|
    t.integer "author_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "editor_id"
    t.boolean "published"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["author_id"], name: "index_blogging_posts_on_author_id"
    t.index ["editor_id"], name: "index_blogging_posts_on_editor_id"
    t.index ["user_id"], name: "index_blogging_posts_on_user_id"
  end

  create_table "demo_features_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "demo_features_morph_demos", force: :cascade do |t|
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "phone"
    t.string "priority"
    t.integer "record_type", null: false
    t.datetime "scheduled_at"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_demo_features_morph_demos_on_category_id"
  end

  create_table "demo_features_product_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.integer "product_id", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_demo_features_product_tags_on_product_id"
    t.index ["tag_id"], name: "index_demo_features_product_tags_on_tag_id"
  end

  create_table "demo_features_products", force: :cascade do |t|
    t.boolean "active", null: false
    t.time "available_from_time", null: false
    t.time "available_until_time", null: false
    t.integer "category_id"
    t.decimal "compare_at_price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.date "discontinue_date", null: false
    t.boolean "featured", null: false
    t.datetime "last_restocked_at", null: false
    t.json "metadata", null: false
    t.string "name", null: false
    t.text "notes", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "published_at", null: false
    t.date "release_date", null: false
    t.string "sku", null: false
    t.string "slug", null: false
    t.json "specifications", null: false
    t.integer "status", null: false
    t.integer "stock_count", null: false
    t.boolean "taxable", null: false
    t.datetime "updated_at", null: false
    t.float "weight", null: false
    t.index ["category_id"], name: "index_demo_features_products_on_category_id"
  end

  create_table "demo_features_reviews", force: :cascade do |t|
    t.datetime "approved_at", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "product_id", null: false
    t.integer "rating", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.boolean "verified", null: false
    t.index ["product_id"], name: "index_demo_features_reviews_on_product_id"
    t.index ["user_id"], name: "index_demo_features_reviews_on_user_id"
  end

  create_table "demo_features_tags", force: :cascade do |t|
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "demo_features_variants", force: :cascade do |t|
    t.boolean "active", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.json "options", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "product_id", null: false
    t.string "sku", null: false
    t.integer "stock_count", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_demo_features_variants_on_product_id"
  end

  create_table "network_devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "ip_address"
    t.string "location_path"
    t.string "mac_address"
    t.json "metadata", null: false
    t.string "name", null: false
    t.string "network_range"
    t.datetime "updated_at", null: false
  end

  create_table "organization_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "organization_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["organization_id", "user_id"], name: "index_organization_users_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_organization_users_on_organization_id"
    t.index ["user_id"], name: "index_organization_users_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organizations_on_name", unique: true
  end

  create_table "user_login_change_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
    t.string "login", null: false
  end

  create_table "user_password_reset_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
  end

  create_table "user_remember_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
  end

  create_table "user_verification_keys", force: :cascade do |t|
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_hash"
    t.integer "status", default: 1, null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "status IN (1, 2)"
  end

  add_foreign_key "admin_active_session_keys", "admins"
  add_foreign_key "admin_authentication_audit_logs", "admins"
  add_foreign_key "admin_lockouts", "admins", column: "id"
  add_foreign_key "admin_login_failures", "admins", column: "id"
  add_foreign_key "admin_otp_keys", "admins", column: "id"
  add_foreign_key "admin_password_reset_keys", "admins", column: "id"
  add_foreign_key "admin_recovery_codes", "admins", column: "id"
  add_foreign_key "admin_remember_keys", "admins", column: "id"
  add_foreign_key "admin_verification_keys", "admins", column: "id"
  add_foreign_key "blogging_comments", "blogging_posts", column: "post_id"
  add_foreign_key "blogging_comments", "users"
  add_foreign_key "blogging_post_metadata", "blogging_posts", column: "post_id", on_delete: :cascade
  add_foreign_key "blogging_posts", "users"
  add_foreign_key "blogging_posts", "users", column: "author_id"
  add_foreign_key "blogging_posts", "users", column: "editor_id"
  add_foreign_key "demo_features_morph_demos", "demo_features_categories", column: "category_id"
  add_foreign_key "demo_features_product_tags", "demo_features_products", column: "product_id"
  add_foreign_key "demo_features_product_tags", "demo_features_tags", column: "tag_id"
  add_foreign_key "demo_features_products", "demo_features_categories", column: "category_id"
  add_foreign_key "demo_features_reviews", "demo_features_products", column: "product_id"
  add_foreign_key "demo_features_reviews", "users"
  add_foreign_key "demo_features_variants", "demo_features_products", column: "product_id"
  add_foreign_key "organization_users", "organizations"
  add_foreign_key "organization_users", "users"
  add_foreign_key "user_login_change_keys", "users", column: "id"
  add_foreign_key "user_password_reset_keys", "users", column: "id"
  add_foreign_key "user_remember_keys", "users", column: "id"
  add_foreign_key "user_verification_keys", "users", column: "id"
end
