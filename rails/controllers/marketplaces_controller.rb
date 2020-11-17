# frozen_string_literal: true

# Marketplaces Controller (flipkart, amazon)
class MarketplacesController < InheritedResource
  def add_mappings
    resource
    Entity.all.each do |entity|
      resource.marketplace_mappings.find_or_initialize_by(
        entity_id: entity.id
      )
    end
  end

  def save_mappings
    if resource.update(resource_params)
      flash[:notice] = t('marketplace_mapping.updated')
      redirect_to marketplaces_path
    else
      flash[:error] = @resource.errors.full_messages.join(' ,')
      render 'add_mappings'
    end
  end

  private

  def nested_params
    [
      marketplace_mappings_attributes: %i[
        id entity_id entity_identifier entity_identifier_value block_present
      ]
    ]
  end

  def after_create_path
    marketplace_add_mappings_path(@resource)
  end
end
