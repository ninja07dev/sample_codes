class Api::V1::ProjectMembersController < ApplicationController
  before_action :load_project

  def index
    project_members = ProjectMember.by_project(@project)
    render json: project_members, each_serializer: ProjectMembersSerializer, status: :ok
  end

  def create
    project_member = CreateProjectMember.call(@project.id, params[:email], params[:role])
    if project_member.success?
      render json: project_member.result, serializer: ProjectMembersSerializer, status: :ok
    else
      render json: { errors: project_member.errors }
    end
  end

  def update
    project_member = ProjectMember.find(params[:id])
    unless project_member.nil?
      project_member.role = params[:role]
      if project_member.save
        render json: project_member, serializer: ProjectMembersSerializer, status: :ok
      else
        render json: { errors: project_member.errors }
      end
    else
      render json: { errors: 'Project member not found' }
    end
  end

  def destroy
    project_member = ProjectMember.find(params[:id])
    project_member.destroy!
    head :ok
  end

  def accept
    project_member = ProjectMember.find(params[:project_member_id])
    if project_member.accept
      head :ok
    else
      render json: { errors: project_member.errors }
    end
  end

  def check_access
    if ProjectMember.find_by(id: params[:id], project: @project, user: @current_user)
      render json: @project, each_serializer: ProjectSerializer, status: :ok, scope: @current_user
    else
      render json: { error: "Your are unauthorized !" }, status: :unauthorized
    end
  end

  protected

  def load_project
    @project = Project.find(params[:project_id])
  end
end
