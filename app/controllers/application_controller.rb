class ApplicationController < ActionController::API
  before_action :authenticate!

  attr_reader :current_user

  private

  def authenticate!
    token = request.headers["Authorization"].to_s.sub(/\ABearer /, "")
    @current_user = User.find_by(api_token: token)
    render json: { error: "unauthorized" }, status: :unauthorized unless @current_user
  end
end
