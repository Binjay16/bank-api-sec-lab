class Account < ApplicationRecord
  belongs_to :user
  has_many :outgoing_transfers, class_name: "Transfer", foreign_key: :from_account_id
  has_many :incoming_transfers, class_name: "Transfer", foreign_key: :to_account_id

  before_create { self.number = (Account.maximum(:id).to_i + 1_000_000_001).to_s }
end
