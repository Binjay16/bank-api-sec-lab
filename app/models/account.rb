class Account < ApplicationRecord
  KINDS = %w[checking savings].freeze

  belongs_to :user
  has_many :outgoing_transfers, class_name: "Transfer", foreign_key: :from_account_id
  has_many :incoming_transfers, class_name: "Transfer", foreign_key: :to_account_id

  validates :kind, inclusion: { in: KINDS }
  validates :balance_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :assign_number, on: :create

  private

  def assign_number
    return if number.present?

    self.number = loop do
      candidate = SecureRandom.random_number(10**10).to_s.rjust(10, "0")
      break candidate unless Account.exists?(number: candidate)
    end
  end
end
