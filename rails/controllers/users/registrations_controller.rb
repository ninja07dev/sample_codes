# frozen_string_literal: true

# Users controlle with devise
class Users::RegistrationsController < Devise::RegistrationsController
  layout 'authentication'
  attr_reader :company_params, :user_params, :phone_number, :company

  def new
    @company = Company.new
    super
  end

  def create
    @company = Company.new(company_params)
    ActiveRecord::Base.transaction do
      @company.save!
      user = @company.users.find_by(phone_number: @company.contact_person_number)
      user.add_role :client
      sign_in(user)
      redirect_to root_path
    end
  rescue ActiveRecord::RecordInvalid
    build_resource(user_params)
    render 'new'
  end

  def company_params
    params[:company].merge!(users_attributes: {'0': user_params.to_h })
    params.require(:company).permit(
      :name, :contact_person_name, :email,
      :contact_person_number, :terms_and_conditions,
      users_attributes: %i[
        id first_name last_name password
        password_confirmation phone_number
      ]
    )
  end

  def user_params
    params[:user].merge!(phone_number: params[:company][:contact_person_number])
    params.require(:user).permit(
      :first_name, :last_name, :password,
      :password_confirmation, :phone_number
    )
  end
end
