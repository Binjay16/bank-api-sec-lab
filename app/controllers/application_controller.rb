class ApplicationController < ActionController::API
  before_action :authenticate!

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not found" }, status: :not_found
  end

  attr_reader :current_user

  private

  def authenticate!
    token = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
    @current_user = token.present? ? User.find_by(api_token: token) : nil
    render json: { error: "unauthorized" }, status: :unauthorized unless @current_user
  end
end
