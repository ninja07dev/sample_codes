class RequestedMarketplacesController < InheritedResource

  before_action :check_uri_presence, only: :create

  def check_uri_presence
    marketplace_website_url = params[:requested_marketplace][:name]
    if Marketplace.exists?(website_url: marketplace_website_url)
      flash[:error] = t('requested_marketplace.duplicate')
      redirect_to root_path and return
    elsif RequestedMarketplace.exists?(name: marketplace_website_url)
      flash[:notice] = t('requested_marketplace.created')
      redirect_to root_path and return
    end
  end

  def after_create_path
    root_path
  end
end
