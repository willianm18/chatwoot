# [fazer.ai fork] Optional per-column color (shares the inbox color palette).
class AddCustomColorToKanbanColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :custom_kanban_columns, :custom_color, :string unless column_exists?(:custom_kanban_columns, :custom_color)
  end
end
