class CreateBankTables < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "customer"
      t.string :api_token
      t.text   :preferences
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :api_token, unique: true

    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :number, null: false
      t.string :kind, null: false, default: "checking"
      t.bigint :balance_cents, null: false, default: 0
      t.timestamps
    end
    add_index :accounts, :number, unique: true

    create_table :transfers do |t|
      t.references :from_account, null: false, foreign_key: { to_table: :accounts }
      t.references :to_account,   null: false, foreign_key: { to_table: :accounts }
      t.bigint :amount_cents, null: false
      t.string :memo
      t.timestamps
    end
  end
end
