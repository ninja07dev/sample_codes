# frozen_string_literal: true

module Api
  module V1
    # static page controller for api
    class StaticPagesController < BaseController
      before_action :invalid_params_for_static, only: :about_us
      skip_before_action :authorize_request, only: :about_us

      def about_us
        if params[:static] == GlobalConstants::STATIC_PAGE_CONTENT_VERSION
          render json: success_response(message: I18n.t('success.up_to_date'))
        else
          render json: success_response(
            message: I18n.t('success.success_message'),
            collection: AboutUs.new(updated_data)
          )
        end
      end

      private

      def updated_data
        data = { version: '' }
        data.merge!(static_data: '') unless params[:static][:about_us] == GlobalConstants::STATIC_PAGE_CONTENT_VERSION['about_us']
        data.merge!(team: '') unless params[:static][:about_us_team] == GlobalConstants::STATIC_PAGE_CONTENT_VERSION['about_us_team']
        data
      end
    end
  end
end
