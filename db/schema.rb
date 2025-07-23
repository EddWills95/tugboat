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

ActiveRecord::Schema[8.0].define(version: 2025_07_23_131127) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ddns_settings", primary_key: "primary_key", id: :string, default: "singleton", force: :cascade do |t|
    t.boolean "enabled", default: false
    t.string "base_domain"
    t.string "aws_access_key_id"
    t.string "aws_secret_access_key"
    t.string "aws_region", default: "us-east-1"
    t.string "route53_hosted_zone_id"
    t.integer "update_interval", default: 300
    t.datetime "last_update", precision: nil
    t.string "current_ip"
    t.string "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.string "docker_image"
    t.integer "port"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "internal_port"
    t.integer "external_port"
    t.string "subdomain"
    t.string "custom_domain"
    t.boolean "ssl_enabled", default: true
    t.string "domain"
    t.boolean "ddns_enabled", default: false
    t.string "ddns_provider"
    t.json "ddns_config", default: {}
    t.string "hostname"
    t.index ["subdomain"], name: "index_projects_on_subdomain", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end
end
