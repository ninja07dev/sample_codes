class SearchesController < ApplicationController

	before_action :response_set, only: [:auction_list]
	def search
		states = []
		@cities = []
		City.search(params[:q]).each do |city|
			unless states.include?(city.county.state.id)
				states << city.county.state.id
				@cities << city
				break if (states.length == 5)
			end
		end
		@state = State.search(params[:q])
		@countries = County.search_json(params[:q])
		@zipcodes = ZipCode.search(params[:q])
		respond_to do |format|
			format.html {}
			format.json {
			@cities = @cities
			@states = @state.limit(5)
			@countries = @countries.limit(5)
			@zipcodes = @zipcodes.limit(5)
			}
		end
	end

	def index
	end

	def auction_list
		@auctions = Auction.all.order('created_at DESC')  if params[:city].blank? && params[:county].blank? && params[:state].blank? && params[:zipcode].blank?
		@auctions = Auction.search(params)
		@auctions_list = @auctions
		@auctions = Auction.filter_search(@auctions, params)
		respond_to do |format|
			format.js
			format.html
		end
	end


	private
	 def response_set
	 	if request.xhr?
		 	response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
			response.headers["Pragma"] = "no-cache"
			response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
	 	end
	 end
end
