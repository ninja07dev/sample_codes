# frozen_string_literal: true

module Api
  module V1
    # static page controller for api
    class ResultsController < BaseController
      def destroy
        @api_current_user.delete_all_associated_results(Feedback::FEEDBACK_TYPE_HASH[:delete_results])
        render json: success_response(message: I18n.t('success.success_message'))
      end
    end
  end
end
