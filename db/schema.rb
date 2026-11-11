ActiveRecord::Schema[8.1].define(version: 2026_01_01_000000) do
  create_table "accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "number", null: false
    t.string "kind", default: "checking", null: false
    t.bigint "balance_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_accounts_on_number", unique: true
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "transfers", force: :cascade do |t|
    t.integer "from_account_id", null: false
    t.integer "to_account_id", null: false
    t.bigint "amount_cents", null: false
    t.string "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_account_id"], name: "index_transfers_on_from_account_id"
    t.index ["to_account_id"], name: "index_transfers_on_to_account_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "customer", null: false
    t.string "api_token"
    t.text "preferences"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "transfers", "accounts", column: "from_account_id"
  add_foreign_key "transfers", "accounts", column: "to_account_id"
end
