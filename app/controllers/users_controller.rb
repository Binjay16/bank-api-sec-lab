class UsersController < ApplicationController
  skip_before_action :authenticate!, only: :create

  def index
    return render(json: { error: "forbidden" }, status: :forbidden) unless current_user.admin?

    render json: User.all.map(&:public_attributes)
  end

  def show
    user = User.find(params[:id])
    return render(json: { error: "not found" }, status: :not_found) unless user == current_user || current_user.admin?

    render json: user.public_attributes
  end

  def create
    user = User.new(signup_params)
    if user.save
      user.accounts.create!(kind: "checking")
      render json: user.public_attributes.merge(token: user.api_token), status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # `role` is deliberately NOT permitted.
  def signup_params
    params.require(:user).permit(:name, :email, :password)
  end
end
