# frozen_string_literal: true

module Api
  module V1
    class EndOfStudyController < BaseController
      def create
        ema_result = nil
        user_study_completion_id = params[:user_study_completion_id]
        
        end_of_study = @api_current_user.study_completions.find_by(id: user_study_completion_id)
        if end_of_study&.update(end_of_study_params)
          unless (Study.general?(end_of_study.study) and end_of_study.study.study_group_notifications.count.to_i == end_of_study.notification.to_i)
            ema_result = StudyCompletion.EMA_custom_results(user_id: end_of_study.user_id, study_id: end_of_study.study_id) 
          end
          render json: success_response(message: I18n.t('success.success_message'),
                                        collection: StudyCompletionSerializer.new(end_of_study),
                                        options: {data: ema_result})
        else
          render_error(message: I18n.t('failure.study_completion_id_not_found'),
                       error_code: :unprocessable_entity,
                       status_code: :unprocessable_entity)
          Rollbar.error(I18n.t('failure.id_not_found', class_name: 'StudyCompletions'),
                        object_info: end_of_study)
        end
      end

      private

      # Never trust parameters from the scary internet, only allow the white list through.
      def end_of_study_params
        params.require(:study_completion).permit(:similar_experiment,
                                                 :taken_survey_before,
                                                 :technical_problems,
                                                 :technical_problem_description,
                                                 :did_you_cheat,
                                                 :cheating_description,
                                                 :people_in_room, :comments)
      end
    end
  end
end
