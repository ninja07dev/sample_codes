# frozen_string_literal: true

module Api
  module V1
    # static page controller for api
    class StudiesController < BaseController
      before_action :published_studies, :check_params
      before_action :check_params, only: :submit_studies
      FIRST_PAGE = 1

      def update_study_detail
        create_or_find_user
        return update_all_study if params[:last_sync_at].blank?

        Study.maximum(:updated_at) > params[:last_sync_at] ? send_updated_studies : up_to_date
      end

      def send_updated_studies
        updated_studies = published_studies.select { |study| study[:updated_at] > params[:last_sync_at] }
        updated_study_in_pages(updated_studies)
      end

      def updated_study_in_pages(updated_studies)
        updated_studies_page = Kaminari.paginate_array(updated_studies).page(page).per(GlobalConstants::STUDIES_PER_PAGE)
        render json: success_response(
          message: I18n.t('success.success_message'),
          collection: StudySerializer.new(updated_studies_page),
          options: { sync: study_last_page?(updated_studies.count, updated_studies_page), published_studies_ids: published_studies.pluck(:id) }
        )
      end

      def study_last_page?(studies_count, page_number)
        return false if studies_count.zero?

        !page_number.last_page?
      end

      def up_to_date
        render json: success_response(message: I18n.t('success.up_to_date'),
                                      options: { sync: false, published_studies_ids: published_studies.pluck(:id) })
      end

      def taken_studies
        study_ids = Study.where(
          id: all_completed_study_ids(completed_studies)
        ).order(study_order: :asc).pluck(:id)
        render json: success_response(
          message: I18n.t('success.success_message'),
          options: { completed_studies_id: study_ids,
                     enrolled_studies_id: enroller_studies_with_reg_date }
        )
      end

      def completed_studies
        StudyCompletion.where(
          study_id: @api_current_user.studies
                                     .is_published
                                     .select(:id)
        )
      end

      def submit_studies
        result = StudyCompletion.create_study_completion(multi_study_params['studies'], params)
        render json: success_response(
          message: I18n.t('success.success_message'),
          collection: require_result?(result.single_study, result.studies_completion),
          options: { created_studies_ids: result.created_studies_ids,
                     error_studies_ids: result.error_studies_ids}
        )
      end

      private

      def all_completed_study_ids(study_completitions)
        study_completitions.includes(:study).reject { |sc| !Study.general?(sc.study) && sc.notification != (sc.study.number_of_notification * sc.study.frequency) }.pluck(:study_id)
      end

      def enroller_studies_with_reg_date
        @api_current_user.user_study_pre_registrations.pluck(:study_id, :reg_date).inject([]) { |arr, record| arr << { study_id: record[0], date: record[1]&.strftime(GlobalConstants::DATE_ONLY_YMD) } }
      end

      def require_result?(single_study, studies_completion)
        StudyCompletionSerializer.new(studies_completion.first) if single_study
      end

      def check_params
        return respond_for_missing_params if params.dig(:studies, :studies).blank?

        params[:studies][:studies].each do |study|
          return respond_for_missing_params unless study[:study].key?('mobile_completion_id')
        end
      end

      def respond_for_missing_params
        render_error(message: I18n.t('failure.something_went_wrong'),
                     error_code: :unprocessable_entity,
                     status_code: :unprocessable_entity)
        Rollbar.error("Error in #{controller_name}##{action_name} while getting params",
                      params: params)
      end

      def multi_study_params
        params.require(:studies).permit(
          studies: [
            study: %i[
              user_id
              study_id
              score
              taken_survey_before
              similar_experiment
              technical_problems
              technical_problem_description
              did_you_cheat
              cheating_description
              people_in_room
              comments
              custom_study_results
              mobile_completion_id
              completed_on
              notification
            ]
          ]
        )
      end

      def page
        params[:page].present? ? params[:page] : FIRST_PAGE
      end

      def create_or_find_user
        UserDeviceSync.create_or_find_by(user_id: @api_current_user.id,
                                         device_id: @api_current_user.device_id)
      end

      def update_all_study
        all_studies = published_studies
        studies_page = Kaminari.paginate_array(all_studies).page(page).per(GlobalConstants::STUDIES_PER_PAGE)
        render json: success_response(message: I18n.t('success.success_message'),
                                      collection: StudySerializer.new(studies_page),
                                      options: { sync: sync_continue?(studies_page) })
      end

      def published_studies
        @published_studies ||= selected_published_studies
      end

      def selected_published_studies
        Study.reject_expired_study(Study.is_published.includes(:rich_text_purpose_of_study,
                                                               :rich_text_understading_the_results, :rich_text_related_research,
                                                               :study_details, :study_group_notifications).sort_by(&:updated_at))
      end
    end
  end
end
