# [fazer.ai fork] Team-tasks Kanban boards. Access = member or account admin;
# only the owner can delete.
class Api::V1::Accounts::Custom::Kanban::BoardsController < Api::V1::Accounts::BaseController
  before_action :set_board, only: [:show, :update, :destroy]
  before_action :authorize_owner!, only: [:destroy]

  def index
    @boards = Custom::Kanban::Board.accessible_by(Current.account_user).order(:name)
  end

  def show; end

  def create
    @board = Current.account.kanban_boards.new(board_params.merge(created_by_id: current_user.id))
    @board.save!
    @board.members.create!(user: current_user)
    @board.default_columns!
    render :show
  end

  def update
    @board.update!(board_params)
    render :show
  end

  def destroy
    @board.destroy!
    head :ok
  end

  private

  def set_board
    @board = Custom::Kanban::Board.accessible_by(Current.account_user).find_by(id: params[:id])
    raise ActiveRecord::RecordNotFound if @board.nil?
  end

  def authorize_owner!
    return if @board.owned_by?(current_user)

    render json: { error: 'Only the board owner can perform this action' }, status: :forbidden
  end

  def board_params
    params.require(:board).permit(:name)
  end
end
