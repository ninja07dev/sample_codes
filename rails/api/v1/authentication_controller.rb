# frozen_string_literal: true

module Api
  module V1
    # Sing In and Sign Out Apis
    class AuthenticationController < BaseController
      before_action :invalid_params, :user_exists?, :confirm_email?, only: :sign_in
      skip_before_action :authorize_request, only: :sign_in

      def sign_in
        if @user.try(:valid_password?, params_user[:password])
          token = JsonWebToken.encode(user_id: @user.id)
          add_token_to_user(token, @user)
          api_current_user(@user&.id)
          render json: success_response(message: I18n.t('devise.sessions.signed_in'),
                                        collection: UserSerializer.new(@user))
        else
          render_error(message: I18n.t('failure.invalid'),
                       error_code: :unauthorized,
                       status_code: :success)
        end
      end

      def sign_out
        decoded = JsonWebToken.decode(auth_token)
        user = User.find(decoded[:user_id])
        if user.update(token: nil, device_id: nil)
          render json: success_response(message: I18n.t('devise.sessions.signed_out'))
        else
          render_error(message: I18n.t('sign_out.error_messages'),
                       error_code: :unauthorized,
                       status_code: :success)
        end
      end

      def user_exists?
        @user = search_user_by_plain_text(email: params_user[:email])
        return if @user.present?

        render_error(message: I18n.t('devise.failure.acc_not_exists'),
                     error_code: :unauthorized,
                     status_code: :success)
      end

      def confirm_email?
        return if @user.confirmed?

        render_error(message: I18n.t('devise.failure.acc_not_exists'),
                     error_code: :unauthorized,
                     status_code: :unauthorized)
      end
    end
  end
end
