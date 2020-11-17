# frozen_string_literal: true

module Api
  class TestController < ApplicationController
    def arc
      @user = User.last
      binding.pry
      render json: { user: @user.serializable_hash, option: { a: 'a', b: 'b', c: 'a'} }
    end
  end
end
