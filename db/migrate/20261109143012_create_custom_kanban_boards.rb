class CreateCustomKanbanBoards < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:custom_kanban_boards)

    create_table :custom_kanban_boards do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.bigint :created_by_id
      t.timestamps
    end
    add_index :custom_kanban_boards, :account_id
  end
end
