# [fazer.ai fork] Join between a Kanban card and an assigned user (board member).
class Custom::Kanban::CardAssignee < ApplicationRecord
  self.table_name = 'custom_kanban_card_assignees'

  belongs_to :card, class_name: 'Custom::Kanban::Card', foreign_key: :custom_kanban_card_id, inverse_of: :card_assignees
  belongs_to :user

  validates :user_id, uniqueness: { scope: :custom_kanban_card_id }
end
