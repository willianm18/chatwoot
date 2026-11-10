# [fazer.ai fork] Kanban columns. Any board member may edit; reorder rewrites positions.
class Api::V1::Accounts::Custom::Kanban::ColumnsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_column, only: [:update, :destroy]

  def create
    @column = @current_board.columns.create!(column_params.merge(position: @current_board.columns.count))
    render :show
  end

  def update
    @column.update!(column_params)
    render :show
  end

  def destroy
    @column.destroy!
    head :ok
  end

  def reorder
    ids = params.require(:column_ids).map(&:to_i)
    @current_board.columns.where(id: ids).find_each do |column|
      column.update!(position: ids.index(column.id))
    end
    head :ok
  end

  private

  def set_column
    @column = @current_board.columns.find(params[:id])
  end

  def column_params
    params.require(:column).permit(:name, :custom_color)
  end
end
