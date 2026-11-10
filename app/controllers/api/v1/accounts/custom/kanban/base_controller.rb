# [fazer.ai fork] Base for Kanban resources nested under a board. Loads the board
# scoped by access (member or account admin) and exposes the owner-only guard.
class Api::V1::Accounts::Custom::Kanban::BaseController < Api::V1::Accounts::BaseController
  before_action :current_board
  after_action :broadcast_board_update

  private

  def current_board
    @current_board ||= Custom::Kanban::Board.accessible_by(Current.account_user).find_by(id: params[:board_id])
    raise ActiveRecord::RecordNotFound if @current_board.nil?
  end

  def authorize_owner!
    return if @current_board.owned_by?(current_user)

    render json: { error: 'Only the board owner can perform this action' }, status: :forbidden
  end

  def broadcast_board_update
    return if request.get? || !response.successful? || @current_board.nil?

    tokens = board_update_tokens
    return if tokens.blank?

    ActionCableBroadcastJob.perform_later(tokens, 'kanban.board.updated', { board_id: @current_board.id })
  end

  # Everyone who can have the board open gets live updates: its members plus the
  # account administrators (admins see every board without being a member).
  def board_update_tokens
    member_ids = @current_board.members.pluck(:user_id)
    admin_ids = @current_board.account.account_users.where(role: :administrator).pluck(:user_id)
    User.where(id: (member_ids + admin_ids).uniq).pluck(:pubsub_token).compact
  end
end
