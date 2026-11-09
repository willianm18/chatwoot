# [fazer.ai fork] Kanban board access list. Only the board owner can change it.
class Api::V1::Accounts::Custom::Kanban::MembersController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :authorize_owner!, only: [:create, :destroy]

  def index
    @members = @current_board.members.includes(:user)
  end

  def create
    user = Current.account.users.find(params.require(:user_id))
    @current_board.members.find_or_create_by!(user: user)
    head :ok
  end

  def destroy
    member = @current_board.members.find(params[:id])
    # The owner is always a member and cannot be removed.
    member.destroy! unless member.user_id == @current_board.created_by_id
    head :ok
  end
end
