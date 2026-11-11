module Reports
  class MonthlySummary
    def initialize(user)
      @user = user
    end

    def generate
      ids = @user.account_ids
      {
        accounts: ids.size,
        outgoing_cents: Transfer.where(from_account_id: ids).sum(:amount_cents),
        incoming_cents: Transfer.where(to_account_id: ids).sum(:amount_cents)
      }
    end
  end
end
