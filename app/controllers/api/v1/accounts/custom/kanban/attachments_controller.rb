# [fazer.ai fork] File attachments on a Kanban card (phase 2). Max 40 MB per file.
class Api::V1::Accounts::Custom::Kanban::AttachmentsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_card

  def create
    file = params.require(:file)
    return render_too_large if file.size > Custom::Kanban::Card::FILE_SIZE_LIMIT

    @card.files.attach(file)
    blob = @card.files.last.blob
    blob.metadata['uploaded_by'] = current_user.id
    blob.save!
    render 'api/v1/accounts/custom/kanban/boards/card', locals: { card: @card.reload }
  end

  def destroy
    attachment = @card.files.find(params[:id])
    return render_forbidden unless can_remove?(attachment)

    attachment.purge
    head :ok
  end

  private

  def set_card
    @card = Custom::Kanban::Card.where(custom_kanban_column_id: @current_board.columns.select(:id)).find(params[:card_id])
  end

  def can_remove?(attachment)
    attachment.blob.metadata['uploaded_by'] == current_user.id || @current_board.owned_by?(current_user)
  end

  def render_forbidden
    render json: { error: 'You cannot remove this attachment' }, status: :forbidden
  end

  def render_too_large
    render json: { error: 'File is too large' }, status: :unprocessable_entity
  end
end
