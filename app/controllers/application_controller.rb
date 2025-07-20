class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!

  # Use devise layout for authentication pages
  layout :layout_by_resource

  protected

  # Redirect to projects page after sign in
  def after_sign_in_path_for(resource)
    projects_path
  end

  # Redirect to projects page after sign out
  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  private

  def layout_by_resource
    if devise_controller?
      "devise"
    else
      "application"
    end
  end
end
