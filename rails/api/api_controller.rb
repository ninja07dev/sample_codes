# frozen_string_literal: true

module Api
  class ApiController < ActionController::API
    include Api::Common::Errorable
    include Api::Common::SuccessResponse
    before_action :authorize_request
    rescue_from ActiveSupport::MessageEncryptor::InvalidMessage, with: :decrypted_key_issue

    def authorize_request
      header = JsonWebToken.decode(auth_token)
      user_id = header[:user_id]
      api_current_user(user_id)
      render_error(message: I18n.t('devise.failure.unauthenticated'), error_code: :unauthorized, status_code: :unauthorized) unless user_present?(user_id)
    rescue ActiveRecord::RecordNotFound => e
      render_error(message: e.message,
                   error_code: :unauthorized,
                   status_code: :unauthorized)
    rescue JWT::DecodeError => e
      render_error(message: e.message,
                   error_code: :unauthorized,
                   status_code: :unauthorized)
    end

    private

    def decrypted_key_issue
      render_error(message: I18n.t('failure.something_went_wrong'),
                   error_code: :unprocessable_entity,
                   status_code: :unprocessable_entity,
                   title: 'ActiveSupport::MessageEncryptor::InvalidMessage')
      Rollbar.error('crypt_keeper key errors')
    end

    def auth_token
      request.headers['X-Person-Project-Token']
    end

    def api_current_user(user_id)
      @api_current_user ||= User.find_by(id: user_id)
    end
  end
end
