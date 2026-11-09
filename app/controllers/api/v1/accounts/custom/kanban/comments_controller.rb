# [fazer.ai fork] Plain-text comments on a Kanban card (phase 2).
class Api::V1::Accounts::Custom::Kanban::CommentsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_card
  before_action :set_comment, only: [:update, :destroy]
  before_action :authorize_author_or_owner!, only: [:update, :destroy]

  def create
    @comment = @card.comments.create!(content: params.require(:content), user: current_user)
    render :show
  end

  def update
    @comment.update!(content: params.require(:content))
    render :show
  end

  def destroy
    @comment.destroy!
    head :ok
  end

  private

  def set_card
    @card = Custom::Kanban::Card.where(custom_kanban_column_id: @current_board.columns.select(:id)).find(params[:card_id])
  end

  def set_comment
    @comment = @card.comments.find(params[:id])
  end

  def authorize_author_or_owner!
    return if @comment.authored_by?(current_user) || @current_board.owned_by?(current_user)

    render json: { error: 'You can only edit your own comments' }, status: :forbidden
  end
end
