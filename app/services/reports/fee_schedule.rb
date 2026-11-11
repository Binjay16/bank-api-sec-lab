module Reports
  class FeeSchedule
    def initialize(_user); end

    def generate
      { wire_fee_cents: 2_500, monthly_maintenance_cents: 500 }
    end
  end
end
