# frozen_string_literal: true

class ProductsController < InheritedResource
  include AuditLog
  before_action :check_valide_uri, only: :create

  attr_reader :marketplace

  def show
    @product_entities = resource.product_entities
  end

  def fetch_latest_data
    ScrapingJob.perform_now(resource.id)
    redirect_to product_path(resource.id)
  end

  def audits
    @audits_heading = t('audit_title')
    render_audit_logs(audit_logs)
  end

  def change_status
    resource.toggle_status
    flash.now[:notice] = t('product.status_change', status: resource.status.titleize)
  rescue
    flash.now[:error] = t('wrong')
    resource
  end

  private

  def audit_logs
    resource.own_and_associated_audits
  end

  def resource_class
    policy_scope(current_company&.products)
  end

  def find_marketplace
    addressable_url = Addressable::URI.parse(params[:product][:product_url])
    url = addressable_url.scheme + '://' + addressable_url.host
    @marketplace = Marketplace.find_by(website_url: url)
  end

  def check_valide_uri
    find_marketplace
    if @marketplace.blank?
      flash[:error] = t('product.valide_marketplace')
      redirect_to new_product_path && return
    else
      required_params[:marketplace_id] = @marketplace.id
    end
  end

  def per_page_resources
    Settings.pagination.products.per_page
  end

  def js_index_page
    'index'
  end
end
