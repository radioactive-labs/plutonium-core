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

ActiveRecord::Schema[8.1].define(version: 2026_01_18_222654) do
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

  create_table "blogging_posts", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.boolean "published"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
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
  add_foreign_key "blogging_posts", "users"
  add_foreign_key "demo_features_morph_demos", "demo_features_categories", column: "category_id"
  add_foreign_key "user_login_change_keys", "users", column: "id"
  add_foreign_key "user_password_reset_keys", "users", column: "id"
  add_foreign_key "user_remember_keys", "users", column: "id"
  add_foreign_key "user_verification_keys", "users", column: "id"
end
