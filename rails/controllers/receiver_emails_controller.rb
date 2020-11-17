# frozen_string_literal: true

class ReceiverEmailsController < InheritedResource
  private

  def resource_class
    policy_scope(current_company&.receiver_emails)
  end
end
