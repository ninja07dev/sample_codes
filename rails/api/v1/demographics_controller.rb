# frozen_string_literal: true

module Api
  module V1
    # user demographic deta
    class DemographicsController < BaseController
      before_action :find_current_user_demographic, only: %i[show edit update]
      skip_before_action :authorize_request, only: :demographics_data

      def show
        success_response_demographic
      end

      def demographics_data
        if params[:version].eql? GlobalConstants::DEMOGRAPHICS[:version]
          render json: success_response(message: I18n.t('success.up_to_date'))
        else
          render json: success_response(
            message: I18n.t('success.success_message'),
            collection: DemographicData.new(version: '', static_data: '')
          )
        end
      end

      def update
        if @demographic.update(demographic_params)
          success_response_demographic
        else
          render_error(message: @demographic.errors.full_messages,
                       error_code: :unprocessable_entity,
                       status_code: :unprocessable_entity)
        end
      rescue Exception => e
        render_error(message: I18n.t('failure.something_went_wrong'),
                     error_code: :unprocessable_entity,
                     status_code: :unprocessable_entity)
        Rollbar.error(e.message, 'some of key\'s are missing',
                      object_info: @demographic)
      end

      private

      def success_response_demographic
        render json: success_response(message: I18n.t('success.success_message'),
                                      collection: DemographicSerializer.new(@demographic))
      end

      def find_current_user_demographic
        @demographic = @api_current_user.demographic || @api_current_user.build_demographic
      end

      def demographic_params
        params[:demographic].merge!(ethnicity: []) if params[:demographic].keys.exclude?('ethnicity')

        if params[:demographic][:ethnicity].exclude?('Other')
          params[:demographic].merge!(ethnicity_description: nil)
        end
        # we can still succeed when user leaves ethnicity blank
        params.require(:demographic).permit(:gender, :total_household_income,
                                            :political_on_social, :political_on_economic, :number_of_people_in_household,
                                            :highest_level_of_education, :language, :other_language, :birth_year, :country,
                                            :postal_code_longest, :postal_code_current, :ethnicity_description).merge(ethnicity: params[:demographic][:ethnicity])
      end
    end
  end
end
