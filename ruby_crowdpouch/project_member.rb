# == Schema Information
#
# Table name: project_members
#
#  id          :integer          not null, primary key
#  project_id  :integer
#  user_id     :integer
#  role        :integer          default(0)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  accepted_at :datetime
#

class ProjectMember < ApplicationRecord

  ROLE_VIEW = 0
  ROLE_WRITE = 1

  validates :project_id, :user_id, :role, presence: true
  validates :role, inclusion: {:in => [ROLE_VIEW, ROLE_WRITE]}

  belongs_to :user
  belongs_to :project

  scope :by_project, -> (project) {where project_id: project.id}
  scope :by_role, -> (role) {where role: role}

  def accept
    self.update_attributes(accepted_at: Time.now)
  end

  def decline
    self.update_attributes(accepted_at: nil)
  end
end
