class UsersController < ApplicationController
  skip_before_action :authenticate!, only: :create

  def index
    return render(json: { error: "forbidden" }, status: :forbidden) unless current_user.role == "admin"

    render json: User.all
  end

  def show
    render json: User.find(params[:id])
  end

  def create
    user = User.new(params.require(:user).permit!)
    if user.save
      user.accounts.create!(kind: "checking")
      render json: user, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
