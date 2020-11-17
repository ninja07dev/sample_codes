# frozen_string_literal: true

module Api
  module V1
    class UserNotificationsController < BaseController
      def user_notifications
        notification = @api_current_user.user_notifications.where('notification_time >= ?', params.dig(:current_time)).order(notification_time: :asc).limit(50)
        render json: success_response(
          message: I18n.t('success.success_message'),
          collection: UserNotificationSerializer.new(notification)
        )
      end
    end
  end
end
