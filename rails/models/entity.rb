# frozen_string_literal: true

# entity model for marketplace product (price,name,..)
class Entity < ApplicationRecord
  NON_DELETABLE_ENTITIES = %w[name price image]
  has_many :product_entities, dependent: :destroy
  has_many :marketplace_mappings, dependent: :destroy
  validates_uniqueness_of :name, case_sensitive: false
end
