class CreateCustomKanbanColumns < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:custom_kanban_columns)

    create_table :custom_kanban_columns do |t|
      t.bigint :custom_kanban_board_id, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :custom_kanban_columns, :custom_kanban_board_id
  end
end
