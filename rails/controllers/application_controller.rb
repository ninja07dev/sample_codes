# frozen_string_literal: true

# ApplicationController
class ApplicationController < ActionController::Base
  include Pundit
  rescue_from Pundit::NotAuthorizedError, Pundit::NotDefinedError, with: :unauthorized_user
  protect_from_forgery
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_raven_context

  def after_sign_in_path_for(resource)
    if resource.has_role?('admin')
      entities_path
    else
      products_path
    end
  end

  def set_raven_context
    Raven.user_context(id: session[:current_user_id]) # or anything else in session
    Raven.extra_context(params: params.to_unsafe_h, url: request.url)
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(
      :sign_up, keys: %i[first_name last_name phone_number email remember_me]
    )
    devise_parameter_sanitizer.permit(:sign_in, keys: %i[phone_number])
  end

  def current_company
    current_user&.company
  end
  helper_method :current_company

  private

  def unauthorized_user(exception)
    flash[:error] = t('pundit.unauthorized')
    redirect_to(request.referrer || root_path)
  end
end
