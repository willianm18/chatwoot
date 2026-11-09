# [fazer.ai fork] Base for Kanban resources nested under a board. Loads the board
# scoped by access (member or account admin) and exposes the owner-only guard.
class Api::V1::Accounts::Custom::Kanban::BaseController < Api::V1::Accounts::BaseController
  before_action :current_board

  private

  def current_board
    @current_board ||= Custom::Kanban::Board.accessible_by(Current.account_user).find_by(id: params[:board_id])
    raise ActiveRecord::RecordNotFound if @current_board.nil?
  end

  def authorize_owner!
    return if @current_board.owned_by?(current_user)

    render json: { error: 'Only the board owner can perform this action' }, status: :forbidden
  end
end
