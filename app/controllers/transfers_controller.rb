class TransfersController < ApplicationController
  class InsufficientFunds < StandardError; end

  def index
    ids = current_user.account_ids
    transfers = Transfer.where(from_account_id: ids).or(Transfer.where(to_account_id: ids))
    if params[:q].present?
      pattern = "%#{Transfer.sanitize_sql_like(params[:q].to_s)}%"
      transfers = transfers.where(Transfer.arel_table[:memo].matches(pattern, "\\"))
    end
    render json: transfers.order(created_at: :desc).limit(100)
  end

  def create
    amount = Integer(params[:amount_cents].to_s, exception: false)
    return unprocessable("amount_cents must be an integer") unless amount

    from = current_user.accounts.find(params[:from_account_id]) # ownership enforced here
    to   = Account.find_by!(number: params[:to_number].to_s)

    transfer = nil
    Account.transaction do
      # Lock both rows in a fixed order (prevents lost updates and deadlocks).
      [from, to].sort_by(&:id).each(&:lock!) # lock! reloads each record in place
      raise InsufficientFunds if from.balance_cents < amount

      transfer = Transfer.create!(from_account: from, to_account: to,
                                  amount_cents: amount, memo: params[:memo])
      from.update!(balance_cents: from.balance_cents - amount)
      to.update!(balance_cents: to.balance_cents + amount)
    end
    render json: transfer, status: :created
  rescue InsufficientFunds
    unprocessable("insufficient funds")
  rescue ActiveRecord::RecordInvalid => e
    unprocessable(e.record.errors.full_messages.to_sentence)
  end

  private

  def unprocessable(message)
    render json: { error: message }, status: :unprocessable_entity
  end
end
