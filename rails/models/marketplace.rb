# frozen_string_literal: true

class Marketplace < ApplicationRecord
  has_many :marketplace_mappings, dependent: :destroy
  has_many :products, dependent: :destroy
  accepts_nested_attributes_for :marketplace_mappings, allow_destroy: true
  validates_uniqueness_of :website_url

  after_commit :remove_requested_marketplace, on: :create

  private

  def remove_requested_marketplace
    RequestedMarketplace.find_by(name: website_url).try(:destroy)
  end
end
