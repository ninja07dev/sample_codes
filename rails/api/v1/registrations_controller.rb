# frozen_string_literal: true

module Api
  module V1
    # API to create and upadate user
    class RegistrationsController < BaseController
      include Api::Common::Errorable
      before_action :invalid_params, :check_password_present, :match_password, only: :update
      skip_before_action :authorize_request, only: %i[create facebook check_new_user resend_confirmation_email new_captcha]
      before_action :fetch_user_email, only: :facebook

      def new_captcha
        if params[:devise_id].present?
          token_value = generate_captcha_token
          number_captcha_value = generate_number_captcha

          store_captcha_data(devise_id: params[:devise_id], 
            token: token_value, number_captcha: number_captcha_value)

          render json: success_response(
            message: I18n.t('success.success_message'),
            options: { token: token_value, 
              number_captcha: number_captcha_value }
          )
        else
          render_error(message: I18n.t('failure.something_went_wrong'),
                       error_code: :unauthorized,
                       status_code: :validation)
        end
      end

      def create
        user = User.new(user_params)
        if read_captcha_data(devise_id: params[:devise_id], 
          token: params[:token], number_captcha: params[:number_captcha])
          Rails.cache.delete("#{params[:devise_id]}generate_captcha")
          if user.save
            render json: success_response(
              message: I18n.t('devise.registrations.signed_up_but_unconfirmed'),
              collection: user
            )
            return
          else
            render_error(message: user.errors.full_messages,
                         error_code: :unauthorized,
                         status_code: :validation)
          end
        else
          render_error(message: I18n.t('failure.captcha_invalid'),
                       error_code: :unauthorized,
                       status_code: :validation)
        end
      end

      def update
        params_user.delete :password unless user_params.key? :password_confirmation
        @api_current_user.attributes = user_params
        if @api_current_user.save
          render json: success_response(message: I18n.t('devise.registrations.updated'),
                                        collection: UserSerializer.new(@api_current_user))
        else
          render_error(message: @api_current_user.errors.full_messages,
                       error_code: :unauthorized,
                       status_code: :success)
        end
      end

      def facebook
        if @email.blank?
          render_error(message: I18n.t('failure.email_not_found'),
                       error_code: :unauthorized,
                       status_code: :unauthorized) && return
        end
        user = find_or_create_user(@email)
        upadate_user_token(user)
      end

      def destroy
        feedback = if params[:delete_study_data]
                     @api_current_user.delete_all_associated_results(
                       Feedback::FEEDBACK_TYPE_HASH[:delete_account_and_results]
                     )
                   else
                     @api_current_user.set_nil_for_all_associated_results(
                       Feedback::FEEDBACK_TYPE_HASH[:delete_account]
                     )
                   end
        @api_current_user.destroy
        render json: success_response(
          message: I18n.t('success.success_message'),
          collection: FeedbackSerializer.new(feedback)
        )
      end

      # to check if the user has already registered via email address
      # Input:: email address
      # Output::
      # Already registered - Error message - User can sign in to continue
      # Not registered - Success message(User can sign up)
      def check_new_user
        user = search_user_by_plain_text(email: params[:email])
        if user
          render_error(message: I18n.t('registrations.check_new_user.email_found'),
                       error_code: :validation,
                       status_code: :validation)
        else
          render json: success_response(message: I18n.t('success.success_message'))
        end
      end

      def resend_confirmation_email
        user = search_user_by_plain_text(email: params[:registration][:email_id])
        if user.present?
          user.send_confirmation_instructions
          render json: success_response(message: I18n.t('devise.confirmations.send_instructions.'))
        else
          return render_error(message: I18n.t('devise.failure.acc_not_exists'),
                              error_code: :unauthorized,
                              status_code: :success)
        end
      rescue Exception => e
        render_error(message: I18n.t('failure.something_went_wrong'),
                     error_code: :unprocessable_entity,
                     status_code: :unprocessable_entity)
        Rollbar.error('user email not found in resend_confirmaiton_email api',
                      class_name: User.class.name)
      end

      private

      def find_or_create_user(email)
        user = search_user_by_plain_text(email: email)
        return user if user.present?

        User.create!(
          email: email,
          password: Devise.friendly_token[0, 20],
          confirmed_at: Time.now
        )
      end

      def fetch_user_email
        reponse = Koala::Facebook::API.new(params_user[:accessToken]).get_object('/me?fields=email')
        @email = reponse['email']
      rescue Exception => e
        render_error(message: I18n.t('failure.something_went_wrong'),
                     error_code: :unauthorized,
                     status_code: :success)
        Rollbar.error('invalid token in API from facebook',
                      error: e)
      end

      def match_password
        key = fetch_password_key
        return if @api_current_user&.valid_password?(params_user[key])

        render_error(message: I18n.t('registrations.passwords.invalid'),
                     error_code: :unauthorized,
                     status_code: :success)
      end

      def fetch_password_key
        current_password_in_params? ? :current_password : :password
      end

      def current_password_in_params?
        params_user.key? :current_password
      end

      def check_password_present
        key = fetch_password_key
        return if params_user[key].present?

        render_error(message: I18n.t('registrations.passwords.can_not_blank'),
                     error_code: :unauthorized,
                     status_code: :success)
      end

      def user_params
        params.require(:user).permit(
          :email,
          :password,
          :password_confirmation,
          demographic_attributes: %i[
            gender
            birth_year
            ethnicity
            ethnicity_description
            highest_level_of_education
            total_household_income
            political_on_social
            political_on_economic
            number_of_people_in_household
            language
            other_language
            postal_code_longest
            postal_code_current
            country
          ]
        )
      end

      def upadate_user_token(user)
        add_token_to_user(JsonWebToken.encode(user_id: user.id), user)
        api_current_user(user.id)
        render json: success_response(
          message: I18n.t('devise.sessions.signed_in'),
          collection: UserSerializer.new(user)
        )
      end

      def store_captcha_data(devise_id:, token:, number_captcha:)
        Rails.cache.write("#{devise_id}generate_captcha", { 'token': token, 'number_captcha': number_captcha })
      end

      def generate_captcha_token
        key = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
        (0...50).map { key[rand(key.length)] }.join
      end

      def generate_number_captcha
        rand(6 ** 6)
      end

      def read_captcha_data(devise_id:, token:, number_captcha:)
        value = Rails.cache.read("#{devise_id}generate_captcha")
        (value.present? and value[:token] == token and value[:number_captcha].to_i == number_captcha.to_i)? true : false
      end
    end
  end
end
