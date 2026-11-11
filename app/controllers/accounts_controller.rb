class AccountsController < ApplicationController
  SORTABLE_COLUMNS = %w[created_at balance_cents kind].freeze

  def index
    column    = SORTABLE_COLUMNS.include?(params[:sort].to_s) ? params[:sort].to_s : "created_at"
    direction = params[:dir].to_s.downcase == "desc" ? :desc : :asc
    render json: current_user.accounts.order(column => direction).map { |a| present(a) }
  end

  def show
    render json: present(current_user.accounts.find(params[:id]))
  end

  # "Confirmation of payee": confirms an account exists and shows a masked owner name.
  def lookup
    account = Account.find_by(number: params[:number].to_s)
    return render(json: { error: "not found" }, status: :not_found) unless account

    render json: { number: account.number, owner: mask(account.user.name) }
  end

  private

  def present(account)
    account.as_json(only: %i[id number kind balance_cents created_at])
  end

  def mask(name)
    name.split.map { |part| part[0] + ("*" * (part.length - 1)) }.join(" ")
  end
end
