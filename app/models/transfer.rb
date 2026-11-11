class Transfer < ApplicationRecord
  MAX_CENTS = 10_000_000 # per-transfer limit (illustrative)

  belongs_to :from_account, class_name: "Account"
  belongs_to :to_account, class_name: "Account"

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_CENTS }
  validates :memo, length: { maximum: 140 }, allow_nil: true
  validate :accounts_differ

  private

  def accounts_differ
    errors.add(:to_account, "must differ from source account") if from_account_id == to_account_id
  end
end
