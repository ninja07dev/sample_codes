# frozen_string_literal: true

# PasswordsController from devise gem
class Users::PasswordsController < Devise::PasswordsController
  layout 'authentication'
end
