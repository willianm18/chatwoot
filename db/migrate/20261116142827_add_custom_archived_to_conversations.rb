class AddCustomArchivedToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :custom_archived, :boolean, default: false, null: false unless column_exists?(:conversations, :custom_archived)

    return if index_exists?(:conversations, :custom_archived, name: 'index_conversations_on_custom_archived')

    add_index :conversations, :custom_archived, where: 'custom_archived = true', name: 'index_conversations_on_custom_archived'
  end
end
