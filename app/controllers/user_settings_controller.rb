class UserSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def edit
    # Show the user settings form
  end

  def update
    if @user.update_with_password(user_params)
      bypass_sign_in(@user) # Keep user signed in after password change
      redirect_to edit_user_settings_path, notice: "Password updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
