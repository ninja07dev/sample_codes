# frozen_string_literal: true

require 'mechanize'

class Scraping
  attr_reader :id

  def initialize(id)
    @id = id
  end

  def collect_data
    data_changes = {}
    marketplace_mappings.each do |mm|
      values_from_scraping(mm)
      product.product_entities.find_or_initialize_by(
        entity_id: mm.entity_id
      ).tap do |product_entity|
        changes_in_entity(product_entity, data_changes)
      end
    end
    EntityChangeMailer.inform_update(product_id: product.id, changes: data_changes).deliver_now if data_changes.present?
    send_empty_node if empty_nodes.present?
  end

  private

  def send_empty_node
    AdminMailer.send_empty_node(empty_nodes: empty_nodes, product_id: product.id).deliver_now
  end

  def values_from_scraping(mpm)
    @entity_block = page.search("[#{mpm.entity_identifier}='#{mpm.entity_identifier_value}']")
    @value = get_value_for_entity(mpm, @entity_block)
  end

  def changes_in_entity(product_entity, data_changes)
    product_entity.value = @value
    unless product_entity.changes.blank? || product_entity.new_record?
      data_changes[product_entity.entity.name] = product_entity.changes['value']
    end
    product_entity.update(value: @value)
  end

  def get_value_for_entity(marketplace_mapping, entity_block)
    return block_present_or_not(entity_block) if marketplace_mapping.block_present

    if entity_block.present?
      return image_path(entity_block) if marketplace_mapping.entity.name == I18n.t('image')

      find_entity_value(entity_block)
    else
      unless marketplace_mapping.block_present
        empty_nodes << marketplace_mapping.entity.name.titleize
      end
      ''
    end
  end

  def image_path(entity_block)
    eval("entity_block.#{marketplace.image_xpath}")
  rescue
    ''
  end

  def find_entity_value(entity_block)
    begin
      entity_block.text.strip
    rescue StandardError
      ''
    end
  end

  def block_present_or_not(entity_block)
    entity_block.present? ? I18n.t('yes') : I18n.t('no')
  end

  def product_url
    Addressable::URI.parse(product.product_url)
  end

  def product
    @product ||= Product.find(id)
  end

  def marketplace
    @marketplace ||= product.marketplace
  end

  def marketplace_mappings
    @marketplace_mappings ||= marketplace.marketplace_mappings
  end

  def agent
    @agent ||= Mechanize.new
  end

  def page
    @page ||= agent.get(product.product_url)
  rescue Mechanize::ResponseCodeError => e
    if all_response_code.include? e.response_code
      e.skip
      sleep 5
    else
      retry
    end
  end

  def all_response_code
    %w[403 404 502]
  end

  def empty_nodes
    @empty_nodes ||= []
  end
end
