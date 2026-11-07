# frozen_string_literal: true

class AddCustomLunchBreakToInboxes < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:inboxes, :custom_lunch_break)

    add_column :inboxes, :custom_lunch_break, :jsonb, default: {}, null: false
  end
end
