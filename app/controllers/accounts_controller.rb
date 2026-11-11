class AccountsController < ApplicationController
  def index
    accounts = current_user.accounts
    accounts = accounts.order(params[:sort]) if params[:sort].present?
    render json: accounts
  end

  def show
    render json: Account.find(params[:id])
  end

  def lookup
    account = Account.where("number = '#{params[:number]}'").first
    if account
      render json: { number: account.number, owner: account.user.name }
    else
      render json: { error: "not found" }, status: :not_found
    end
  end
end
