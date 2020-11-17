# This concern is used to paginate and render audit logs in all controllers.
# frozen_string_literal: true

module AuditLog
  extend ActiveSupport::Concern

  private

  def paginate_audit_logs(resource)
    resource = resource.group_by { |r| r.created_at.to_date }.to_a.to_h.sort.reverse
    Kaminari.paginate_array(resource).page(params[:page]).per(1) # Audit logs of 1 day per page
  end

  def render_audit_logs(resource)
    @audits = paginate_audit_logs(resource)
    respond_to do |format|
      format.html { render 'shared/audit_logs', locals: { audits: @audits } }
      format.js { render 'shared/audit_logs' }
    end
  end
end
