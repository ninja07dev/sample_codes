# frozen_string_literal: true

module Api
  module V1
    class ContactsController < ApiController
      skip_before_action :authorize_request, only: :create

      def create
        contact = Contact.new(contact_params)

        # Verify captcha to save contact us
        if read_captcha_data(devise_id: params[:devise_id], 
          token: params[:token], number_captcha: params[:number_captcha]) 
          Rails.cache.delete("#{params[:devise_id]}generate_captcha")
          if contact.save
            mailer = ContactFormMailer.contact_response(contact)
            mailer.deliver!
            render json: success_response(message: I18n.t('contact_us.messages.success'))
          else
            render_error(message: contact.errors.full_messages,
                         error_code: :bad_request,
                         status_code: :validation)
          end
        else
          render_error(message: I18n.t('failure.captcha_invalid'),
                       error_code: :bad_request,
                       status_code: :validation)
        end
      end

      private

      # Never trust parameters from the scary internet, only allow the white list through.
      def contact_params
        params.require(:contact).permit(
          :first_name,
          :last_name,
          :email_address,
          :questions_comments
        )
      end

      def read_captcha_data(devise_id:, token:, number_captcha:)
        value = Rails.cache.read("#{devise_id}generate_captcha")
        (value.present? and value[:token] == token and value[:number_captcha].to_i == number_captcha.to_i)? true : false
      end
    end
  end
end
