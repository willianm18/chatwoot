class CreateCustomKanbanLabels < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:custom_kanban_labels)

    create_table :custom_kanban_labels do |t|
      t.bigint :custom_kanban_board_id, null: false
      t.string :name, null: false
      t.string :color, null: false
      t.timestamps
    end
    add_index :custom_kanban_labels, :custom_kanban_board_id
  end
end
