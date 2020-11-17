# frozen_string_literal: true

module Api
  module V1
    # basecontroller for comman logic
    class BaseController < ApiController
      FIRST_PAGE = 1
      def user_present?(user_id)
        user = User.find_by(id: user_id)
        user && user&.token.eql?(auth_token) && user&.device_id.eql?(request.headers['Device-Id'])
      end

      def invalid_params
        return if params_user.present?

        render_error(
          message: I18n.t('failure.something_went_wrong'),
          error_code: :unprocessable_entity,
          status_code: :success)
      end

      def params_user
        params[:user]
      end

      def invalid_params_for_static
        return if params[:static].present?

        render_error(
          message: I18n.t('failure.something_went_wrong'),
          error_code: :unprocessable_entity,
          status_code: :success
        )
      end

      def add_token_to_user(token, user)
        user.update(token: token, device_id: params_user['Device-Id'])
      end

      def page
        params[:page].present? ? params[:page] : FIRST_PAGE
      end

      def sync_continue?(pages)
        pages.blank? ? false : !pages.last_page?
      end

      def search_user_by_plain_text(email:)
        User.search_by_plaintext(:email, email)&.first
      end
    end
  end
end
