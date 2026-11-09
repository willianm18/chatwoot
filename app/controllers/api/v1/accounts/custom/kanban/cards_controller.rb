# [fazer.ai fork] Kanban cards. Create/update accept labels and an assignee (an
# account agent). `move` relocates the card and resequences the target column.
class Api::V1::Accounts::Custom::Kanban::CardsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_card, only: [:update, :destroy, :move]
  before_action :validate_assignee!, only: [:create, :update]

  def create
    column = @current_board.columns.find(params.require(:card).require(:column_id))
    @card = column.cards.create!(card_params.merge(position: column.cards.count, created_by_id: current_user.id))
    assign_labels(@card)
    render :show
  end

  def update
    @card.update!(card_params)
    assign_labels(@card) if params[:card].key?(:label_ids)
    render :show
  end

  def destroy
    @card.destroy!
    head :ok
  end

  # Move the card to column_id at position, resequencing the target column.
  def move
    target = @current_board.columns.find(params.require(:column_id))
    position = params.require(:position).to_i
    @card.update!(column: target)
    siblings = target.cards.where.not(id: @card.id).to_a
    siblings.insert(position, @card)
    siblings.each_with_index { |card, index| card.update!(position: index) }
    head :ok
  end

  private

  def set_card
    @card = Custom::Kanban::Card.where(custom_kanban_column_id: @current_board.columns.select(:id)).find(params[:id])
  end

  def validate_assignee!
    assignee_id = params.dig(:card, :assignee_id)
    return if assignee_id.blank? || Current.account.user_ids.include?(assignee_id.to_i)

    render json: { error: 'Assignee must be an agent of this account' }, status: :unprocessable_entity
  end

  def assign_labels(card)
    ids = Array(params.dig(:card, :label_ids)).map(&:to_i)
    card.label_ids = @current_board.labels.where(id: ids).pluck(:id)
  end

  def card_params
    params.require(:card).permit(:title, :description, :assignee_id, :due_date)
  end
end
