class ReportsController < ApplicationController
  def show
    report = params[:type].constantize.new(current_user)
    render json: report.generate
  end
end
