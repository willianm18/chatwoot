class CreateCustomKanbanCards < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:custom_kanban_cards)

    create_table :custom_kanban_cards do |t|
      t.bigint :custom_kanban_column_id, null: false
      t.string :title, null: false
      t.text :description
      t.bigint :assignee_id
      t.date :due_date
      t.integer :position, null: false, default: 0
      t.bigint :created_by_id
      t.timestamps
    end
    add_index :custom_kanban_cards, :custom_kanban_column_id
  end
end
