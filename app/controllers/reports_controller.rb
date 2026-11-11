class ReportsController < ApplicationController
  def show
    report =
      case params[:type].to_s
      when "monthly_summary" then Reports::MonthlySummary
      when "fee_schedule"    then Reports::FeeSchedule
      end
    return render(json: { error: "unknown report" }, status: :not_found) unless report

    render json: report.new(current_user).generate
  end
end
