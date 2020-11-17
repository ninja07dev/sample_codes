# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    redirection_path = if current_user&.has_role?(:client)
                         products_path
                       elsif current_user&.has_role?(:admin)
                         entities_path
                       else
                         new_user_session_path
                       end

    redirect_to redirection_path
  end
end
