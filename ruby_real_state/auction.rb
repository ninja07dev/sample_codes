class Auction < ApplicationRecord
  extend FriendlyId
  audited

  belongs_to :auctioneer
  belongs_to :property

  has_one :address, as: :addressable, dependent: :destroy

  friendly_id :auction_slug, use: :slugged

  after_create :create_new_listing_notification
  after_save :generate_update_messages, on: :update

  has_many :documents, as: :documentable

  has_many :courthouse_auctions
  has_many :courthouse, through: :courthouse_auctions

  validates :auction_type,     presence: true
  validates :property_id,      presence: true
  validates :auction_date,     presence: true
  validates :auction_time,     presence: true
  validates :auctioneer_id,    presence: true
  validates :original_listing, presence: true

  scope :upcoming, -> { where('auction_date >= ?', Date.today) }
  scope :expired, -> { where('auction_date < ?', Date.today) }

  enum auction_type: [:online, :in_person]
  enum location_type: [:on_premises, :separate_location, :courthouse]

  accepts_nested_attributes_for :address, :courthouse_auctions

  def auction_slug
    property&.address&.slugged_address
  end

  def self.by_month(month)
    where(:auction_date => month.beginning_of_month..month.end_of_month).order(:auction_date)
  end

  def place_of_auction
    return "" if online?
    return "" if courthouse?
    return property.address.full_address if on_premises?
    return ""if separate_location?
  end

  def place_of_auction_icon
    return "icons/online.svg" if online?
    return "icons/court.svg" if courthouse?
    return "icons/house-1.svg" if on_premises? || separate_location?
  end

  def place_of_auction_description
    return "online" if online?
    return "at the #{courthouse.name}" if courthouse?
    return "on the premises" if on_premises?
    return "at a separate location" if separate_location?
  end

  def create_new_listing_notification
    Notification.create_new_listing_notification(self.id)
  end

  def create_notifications
    Notification.create_notifications(self.id)
  end

  def generate_update_messages
    NotificationDetail.generate_notification_details_for_recently_updated(self.id)
  end

  # Search through City, State, County & ZipCode
  def self.search(params)
    case
    when params[:city].present? && params[:state].present? then auctions = Auction.joins(property: [address: [:city,:state]]).where('cities.name LIKE (?) AND states.two_digit_code LIKE (?)', "#{params[:city]}", "#{params[:state]}")
    when params[:city].present? then auctions = Auction.joins(property: [address: [:city]]).where('cities.name LIKE (?)', "#{params[:city]}")
    when params[:county].present? && params[:state].present? then auctions = Auction.joins(property: [address: [:county,:state]]).where('counties.name LIKE (?) AND states.two_digit_code LIKE (?)', "#{params[:county]}", "#{params[:state]}")
    when params[:county].present? then auctions = Auction.joins(property: [address: [:county]]).where('counties.name LIKE (?)', "#{params[:county]}")
    when params[:state].present? then auctions = Auction.joins(property: [address: [:state]]).where('states.name LIKE (?)', "#{params[:state]}")
    when params[:zipcode].present? then auctions = Auction.joins(property: [address: [:zip_code]]).where('zip_codes.code LIKE (?)', "#{params[:zipcode]}")
    end
    return auctions
  end

  # Filters
  def self.filter_search(auctions, params)
    unless auctions.blank?
      auctions = self.filter_by_auctioneer(auctions, params)
      auctions = self.filter_by_required_deposit(auctions, params)
      auctions = self.filter_by_auction_format(auctions,params)
      auctions = self.filter_by_auction_date(auctions,params)
      auctions = self.filter_by_pre_bids_accepted(auctions,params)
      auctions = self.filter_by_year_built(auctions,params)
      auctions = self.filter_by_minmax_lot_size(auctions,params)
      auctions = self.filter_by_minmax_stories(auctions,params)
      auctions = self.filter_by_minmax_bids(auctions,params)
      auctions = self.filter_by_minmum_bids(auctions,params)
      auctions = self.filter_by_minmum_opening_bids(auctions,params)
      auctions = self.filter_by_minmum_square_feet(auctions,params)
      auctions = self.filter_by_assets_type(auctions,params)
      auctions = self.filter_by_auction_vacant(auctions,params)
      auctions = self.filter_by_bed_rooms(auctions, params)
      auctions = self.filter_by_bath_rooms(auctions, params)
      auctions = self.filter_by_buyers_premium_amount(auctions, params)
      auctions = self.filter_by_buyers_premium_percentage(auctions, params)
      auctions = self.filter_by_property_type(auctions, params)
    end
  end

  # Filter through Auctioneer
  def self.filter_by_auctioneer(auctions, params)
    return auctions.joins(:auctioneer).where(auctioneers: {name: params[:auctioneer].split(',')}) if params[:auctioneer].present?
    return auctions unless params[:auctioneer].present?
  end

  # Filter through required_deposit

  def self.filter_by_required_deposit(auctions, params)
    if params[:required_deposit].present?
      if  params[:required_deposit].split("-").include? "min"
        return auctions.where('initial_deposit >= ?',params[:required_deposit].split("-")[0])
      elsif params[:required_deposit].split("-").include? "max"
        return auctions.where('initial_deposit <= ?',params[:required_deposit].split("-")[0])
      else
      return auctions.where('initial_deposit BETWEEN ? AND ?',params[:required_deposit].split("-")[0],params[:required_deposit].split("-")[1])
      end
    end
    return auctions
  end

  def self.filter_by_auction_date(auctions, params)
    if params[:auction_date].present?
      if  params[:auction_date].split("-").include? "min"
        return auctions.where('auction_date >= ?',params[:auction_date].split("-")[0])
      elsif params[:auction_date].split("-").include? "max"
        return auctions.where('auction_date <= ?',params[:auction_date].split("-")[0])
      else
      return auctions.where('auction_date BETWEEN ? AND ?',params[:auction_date].split("-")[0],params[:auction_date].split("-")[1])
      end
    end
    return auctions
  end

  # Filter through Auction Format
  def self.filter_by_auction_format(auctions, params)
    if params[:auction_type].present?
      if params[:auction_type].include? 'any'
        return auctions
      else
        return auctions.where(auction_type: params[:auction_type].split(',').flatten)
      end
    end
    return auctions
  end

  # Filter by pre bids accepted
  def self.filter_by_pre_bids_accepted(auctions, params)
    if params[:bids_accepted].present?
      if  params[:bids_accepted].include? "any"
        return auctions
      elsif ((params[:bids_accepted].include? "true") &&  (params[:bids_accepted].include? "false"))
        return auctions
      elsif (params[:bids_accepted].include? "true")
        return auctions.where('pre_bids_accepted = ?', "true")
      elsif  (params[:bids_accepted].include? "false")
        return auctions.where('pre_bids_accepted = ?', "false")
      end
    end
    return auctions
  end

  def self.filter_by_year_built(auctions, params)
    if params[:year_built].present?
      if  params[:year_built].split("-").include? "min"
        return auctions.where('year_built >= ?',params[:year_built].split("-")[0])
      elsif params[:year_built].split("-").include? "max"
        return auctions.where('year_built <= ?',params[:year_built].split("-")[0])
      else
      return auctions.where('year_built BETWEEN ? AND ?',params[:year_built].split("-")[0],params[:year_built].split("-")[1])
      end
    end
    return auctions
  end

  def self.filter_by_minmax_lot_size(auctions, params)
    if params[:lot_size].present?
      if  params[:lot_size].split("-").include? "min"
        return auctions.where('size >= ?',params[:lot_size].split("-")[0])
      elsif params[:lot_size].split("-").include? "max"
        return auctions.where('size <= ?',params[:lot_size].split("-")[0])
      else
      return auctions.where('size BETWEEN ? AND ?',params[:lot_size].split("-")[0],params[:lot_size].split("-")[1])
      end
    end
    return auctions
  end

  def self.filter_by_minmax_stories(auctions, params)
    if params[:stories].present?
      if  params[:stories].split("-").include? "min"
        return auctions.where('stories >= ?',params[:stories].split("-")[0])
      elsif params[:stories].split("-").include? "max"
        return auctions.where('stories <= ?',params[:stories].split("-")[0])
      else
        return auctions.where('stories BETWEEN ? AND ?',params[:stories].split("-")[0],params[:stories].split("-")[1])
      end
    end

    return auctions
  end

  def self.filter_by_minmax_bids(auctions, params)
    if params[:suggestion_bids].present?
      if  params[:suggestion_bids].split("-").include? "min"
        return auctions.where('suggested_starting_bid >= ?',params[:suggestion_bids].split("-")[0])
      elsif params[:suggestion_bids].split("-").include? "max"
        return auctions.where('suggested_starting_bid <= ?',params[:suggestion_bids].split("-")[0])
      else
      return auctions.where('suggested_starting_bid BETWEEN ? AND ?',params[:suggestion_bids].split("-")[0],params[:suggestion_bids].split("-")[1])
      end
    end

    return auctions
  end

  def self.filter_by_minmum_bids(auctions, params)
    if params[:minimum_bids].present?
      if  params[:minimum_bids].split("-").include? "min"
        return auctions.where('minimum_bid >= ?',params[:minimum_bids].split("-")[0])
      elsif params[:minimum_bids].split("-").include? "max"
        return auctions.where('minimum_bid <= ?',params[:minimum_bids].split("-")[0])
      else
      return auctions.where('minimum_bid BETWEEN ? AND ?',params[:minimum_bids].split("-")[0],params[:minimum_bids].split("-")[1])
      end
    end

    return auctions
  end

  def self.filter_by_minmum_opening_bids(auctions, params)
    if params[:opening_bid].present?
      if  params[:opening_bid].split("-").include? "min"
        return auctions.where('suggested_starting_bid >= ?',params[:opening_bid].split("-")[0])
      elsif params[:opening_bid].split("-").include? "max"
        return auctions.where('suggested_starting_bid <= ?',params[:opening_bid].split("-")[0])
      else
      return auctions.where('suggested_starting_bid BETWEEN ? AND ?',params[:opening_bid].split("-")[0],params[:opening_bid].split("-")[1])
      end
    end

    return auctions
  end

  def self.filter_by_minmum_square_feet(auctions, params)
    if params[:square_feet].present?
      if  params[:square_feet].split("-").include? "min"
        return auctions.where('size >= ?',params[:square_feet].split("-")[0])
      elsif params[:square_feet].split("-").include? "max"
        return auctions.where('size <= ?',params[:square_feet].split("-")[0])
      else
      return auctions.where('size BETWEEN ? AND ?',params[:square_feet].split("-")[0],params[:square_feet].split("-")[1])
      end
    end
    return auctions
  end

  def self.filter_by_assets_type(auctions, params)
    if params[:assets_type].present?
      conditions = []
      conditions.push("bank_owned = ?") if params[:assets_type].include? "bank_owned"
      conditions.push("city_owned = ?")  if  params[:assets_type].include? "city_owned"
      conditions.push("foreclosure = ?") if params[:assets_type].include? "foreclosure"
      count = conditions.count
      conditions_array  = conditions.join(' OR ')
      conditions_arr = count.times.map{ "true" }
      conditions_arr.unshift(conditions_array)
     return auctions.where(conditions_arr)
    end
    return auctions
  end

  def self.filter_by_auction_vacant(auctions, params)
    if params[:vacant].present?
      return auctions.where('vacant = ?', "true")
    end
    return auctions
  end

  def self.filter_by_bed_rooms(auctions, params)
    if (params[:beds].present? && params[:beds] != "any")
      return auctions.where('bedrooms >= ?', params[:beds])
    end
    return auctions
  end

  def self.filter_by_bath_rooms(auctions, params)
    if (params[:baths].present? && params[:baths] != "any" )
      return auctions.where('full_baths >= ?', params[:baths])
    end
    return auctions
  end

  def self.filter_by_buyers_premium_amount(auctions, params)
    if params[:premium_dollar].present?
      if  params[:premium_dollar].split("-").include? "min"
        return auctions.where('buyers_premium_amount >= ?',params[:premium_dollar].split("-")[0])
      elsif params[:premium_dollar].split("-").include? "max"
        return auctions.where('buyers_premium_amount <= ?',params[:premium_dollar].split("-")[0])
      else
      return auctions.where('buyers_premium_amount BETWEEN ? AND ?',params[:premium_dollar].split("-")[0],params[:premium_dollar].split("-")[1])
      end
    end
    return auctions
  end

  def self.filter_by_buyers_premium_percentage(auctions, params)
    if params[:premium_percent].present?
      if  params[:premium_percent].split("-").include? "min"
        return auctions.where('buyers_premium_percentage >= ?',params[:premium_percent].split("-")[0])
      elsif params[:premium_percent].split("-").include? "max"
        return auctions.where('buyers_premium_percentage <= ?',params[:premium_percent].split("-")[0])
      else
      return auctions.where('buyers_premium_percentage BETWEEN ? AND ?',params[:premium_percent].split("-")[0],params[:premium_percent].split("-")[1])
      end
    end
    return auctions
  end

  def self.filter_by_property_type(auctions, params)
    return  auctions.where('properties.property_type_id IN (?)',params[:property_type].split(",").flatten) if params[:property_type].present?
    return auctions unless params[:property_type].present?
  end
end
