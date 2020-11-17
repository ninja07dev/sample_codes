# frozen_string_literal: true

module Api
  module V1
    # TO forgot password
    class PasswordsController < Devise::PasswordsController
      skip_before_action :verify_authenticity_token
      include Api::Common::SuccessResponse
      include Api::Common::Errorable

      def create
        resource = User.search_by_plaintext(:email, resource_params[:email])&.first
        if resource.present?
          resource.send_reset_password_instructions
          if successfully_sent?(resource)
            render json: success_response(message: I18n.t('devise.passwords.send_instructions'))
          else
            render_error(message: I18n.t('failure.something_went_wrong'),
                         error_code: :unprocessable_entity,
                         status_code: :unprocessable_entity)
          end
        else
          render_error(message: I18n.t('registrations.passwords.forgot_password.email_not_found'),
                       error_code: :unprocessable_entity,
                       status_code: :unprocessable_entity)
        end
      end
    end
  end
end
