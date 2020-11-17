# frozen_string_literal: true

module Api
  module V1
    class SensorDetailsController < BaseController
      def create
        sensor = @api_current_user.user_sensor_details.new(sensor_params)
        if sensor.save
          render json: success_response(message: I18n.t('success.success_message'))
        else
          render_error(message: I18n.t('failure.something_went_wrong'),
                       error_code: :unprocessable_entity,
                       status_code: :unprocessable_entity)
          Rollbar.error(I18n.t('failure.error_in_obj_on_saving', class_name: sensor.class.name),
                        object_info: sensor,
                        errors: sensor.errors.messages)
        end
      rescue Exception => e
        render_error(message: I18n.t('failure.something_went_wrong'),
                     error_code: :unprocessable_entity,
                     status_code: :unprocessable_entity)
        Rollbar.error(e.message,
                      object_info: sensor)
      end

      private

      def sensor_params
        params.require(:sensor).permit(
          :accelerometer,
          :ambient_light
        )
      end
    end
  end
end
