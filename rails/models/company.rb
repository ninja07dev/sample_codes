# frozen_string_literal: true

# company model
class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :receiver_emails, dependent: :destroy
  accepts_nested_attributes_for :users, allow_destroy: true

  validates :terms_and_conditions, acceptance: { message: 'must be accepted' }
end
