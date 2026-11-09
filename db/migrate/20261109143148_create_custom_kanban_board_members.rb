class CreateCustomKanbanBoardMembers < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:custom_kanban_board_members)

    create_table :custom_kanban_board_members do |t|
      t.bigint :custom_kanban_board_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :custom_kanban_board_members,
              %i[custom_kanban_board_id user_id],
              unique: true, name: 'idx_custom_kanban_board_members_on_board_and_user'
  end
end
