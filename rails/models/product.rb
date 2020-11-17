# frozen_string_literal: true

class Product < ApplicationRecord
  
  enum status: %i[active inactive]

  belongs_to :marketplace
  belongs_to :company
  has_many :product_entities, dependent: :destroy
  after_commit :call_scraping_job, on: :create

  audited only: :status

  has_associated_audits

  def call_scraping_job
    ScrapingJob.perform_now(id)
  end

  def toggle_status
    active? ? inactive! : active!
  end
end
