# [fazer.ai fork] Multiple assignees per Kanban card. Replaces the single
# custom_kanban_cards.assignee_id with a join table, backfilling existing values.
class AddCardAssigneesToKanban < ActiveRecord::Migration[7.2]
  def up
    unless table_exists?(:custom_kanban_card_assignees)
      create_table :custom_kanban_card_assignees do |t|
        t.bigint :custom_kanban_card_id, null: false
        t.bigint :user_id, null: false
        t.timestamps
      end
      add_index :custom_kanban_card_assignees, :custom_kanban_card_id,
                name: 'index_kanban_card_assignees_on_card'
      add_index :custom_kanban_card_assignees, %i[custom_kanban_card_id user_id],
                unique: true, name: 'index_kanban_card_assignees_on_card_and_user'
    end

    return unless column_exists?(:custom_kanban_cards, :assignee_id)

    cards = Class.new(ActiveRecord::Base) { self.table_name = 'custom_kanban_cards' }
    joins = Class.new(ActiveRecord::Base) { self.table_name = 'custom_kanban_card_assignees' }
    cards.where.not(assignee_id: nil).find_each do |card|
      joins.find_or_create_by!(custom_kanban_card_id: card.id, user_id: card.assignee_id)
    end

    remove_column :custom_kanban_cards, :assignee_id
  end

  def down
    add_column :custom_kanban_cards, :assignee_id, :bigint unless column_exists?(:custom_kanban_cards, :assignee_id)
    drop_table :custom_kanban_card_assignees if table_exists?(:custom_kanban_card_assignees)
  end
end
