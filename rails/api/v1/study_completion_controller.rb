# frozen_string_literal: true

# frozen_string_literal true

module Api
  module V1
    class StudyCompletionController < BaseController
      def all_results
        all_result = @api_current_user.study_completions.order(updated_at: :desc).uniq(&:study_id)
        completed_studies = Kaminari.paginate_array(all_result).page(page).per(GlobalConstants::STUDIES_PER_PAGE)
        render json: success_response(
          message: I18n.t('success.success_message'),
          collection: StudyCompletionSerializer.new(completed_studies),
          options: { sync: sync_continue?(completed_studies), total_results: all_result.count }
        )
      end
    end
  end
end
