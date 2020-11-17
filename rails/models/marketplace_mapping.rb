# frozen_string_literal: true

class MarketplaceMapping < ApplicationRecord
  belongs_to :marketplace, inverse_of: :marketplace_mappings
  belongs_to :entity
end
