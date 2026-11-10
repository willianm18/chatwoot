# [fazer.ai fork] Base for Kanban resources nested under a board. Loads the board
# scoped by access (members only) and exposes the owner-only guard.
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

    # account_id is required: the dashboard cable drops events whose account_id
    # does not match the current account (ActionCableConnector#isAValidEvent).
    ActionCableBroadcastJob.perform_later(
      tokens, 'kanban.board.updated', { board_id: @current_board.id, account_id: @current_board.account_id }
    )
  end

  # Everyone who can have the board open gets live updates: its members. Account
  # role no longer grants access, so admins who are not members are not notified.
  def board_update_tokens
    @current_board.member_users.pluck(:pubsub_token).compact
  end
end
