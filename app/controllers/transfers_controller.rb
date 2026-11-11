class TransfersController < ApplicationController
  def index
    transfers = Transfer.where(from_account_id: current_user.account_ids)
    transfers = transfers.where("memo LIKE '%#{params[:q]}%'") if params[:q].present?
    render json: transfers
  end

  def create
    from   = Account.find(params[:from_account_id])
    to     = Account.find_by!(number: params[:to_number])
    amount = params[:amount_cents].to_i

    from.update!(balance_cents: from.balance_cents - amount)
    to.update!(balance_cents: to.balance_cents + amount)
    transfer = Transfer.create!(from_account: from, to_account: to,
                                amount_cents: amount, memo: params[:memo])
    render json: transfer, status: :created
  end
end
