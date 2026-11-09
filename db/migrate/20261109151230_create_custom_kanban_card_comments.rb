class CreateCustomKanbanCardComments < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:custom_kanban_card_comments)

    create_table :custom_kanban_card_comments do |t|
      t.bigint :custom_kanban_card_id, null: false
      t.bigint :user_id, null: false
      t.text :content, null: false
      t.timestamps
    end
    add_index :custom_kanban_card_comments, :custom_kanban_card_id
  end
end
