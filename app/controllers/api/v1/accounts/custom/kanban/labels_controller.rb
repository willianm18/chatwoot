# [fazer.ai fork] Per-board Kanban labels. Any board member may manage them.
class Api::V1::Accounts::Custom::Kanban::LabelsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_label, only: [:update, :destroy]

  def create
    @label = @current_board.labels.create!(label_params)
    render :show
  end

  def update
    @label.update!(label_params)
    render :show
  end

  def destroy
    @label.destroy!
    head :ok
  end

  private

  def set_label
    @label = @current_board.labels.find(params[:id])
  end

  def label_params
    params.require(:label).permit(:name, :color)
  end
end
