class CreateCustomKanbanCardLabels < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:custom_kanban_card_labels)

    create_table :custom_kanban_card_labels do |t|
      t.bigint :custom_kanban_card_id, null: false
      t.bigint :custom_kanban_label_id, null: false
      t.timestamps
    end
    add_index :custom_kanban_card_labels,
              %i[custom_kanban_card_id custom_kanban_label_id],
              unique: true, name: 'idx_custom_kanban_card_labels_on_card_and_label'
  end
end
