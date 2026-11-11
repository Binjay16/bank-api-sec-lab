class SessionsController < ApplicationController
  skip_before_action :authenticate!

  def create
    user = User.find_by(email: params[:email])
    if user && user.authenticate(params[:password])
      render json: { token: user.api_token, user: user }
    else
      render json: { error: "invalid credentials" }, status: :unauthorized
    end
  end

  def destroy
    redirect_to params[:return_to] || "/", allow_other_host: true
  end
end
