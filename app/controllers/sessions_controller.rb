class SessionsController < ApplicationController
  skip_before_action :authenticate!

  # Redirect targets are chosen from a server-side list, never taken from the request.
  RETURN_PATHS = { "home" => "/", "login" => "/login" }.freeze

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    if user&.authenticate(params[:password].to_s)
      render json: { token: user.api_token, user: user.public_attributes }
    else
      render json: { error: "invalid credentials" }, status: :unauthorized
    end
  end

  def destroy
    redirect_to RETURN_PATHS.fetch(params[:return_to].to_s, "/")
  end
end
