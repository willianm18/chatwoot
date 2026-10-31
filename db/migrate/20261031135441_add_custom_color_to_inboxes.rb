# frozen_string_literal: true

class AddCustomColorToInboxes < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:inboxes, :custom_color)

    add_column :inboxes, :custom_color, :string
  end
end
