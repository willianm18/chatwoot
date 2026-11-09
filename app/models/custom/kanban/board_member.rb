# [fazer.ai fork] Access list for a Kanban board (simple access model — see design spec §2).
class Custom::Kanban::BoardMember < ApplicationRecord
  self.table_name = 'custom_kanban_board_members'

  belongs_to :board, class_name: 'Custom::Kanban::Board', foreign_key: :custom_kanban_board_id, inverse_of: :members
  belongs_to :user

  validates :user_id, uniqueness: { scope: :custom_kanban_board_id }
end
