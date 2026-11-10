# [fazer.ai fork] A column of a Kanban board, ordered by position.
class Custom::Kanban::Column < ApplicationRecord
  self.table_name = 'custom_kanban_columns'

  belongs_to :board, class_name: 'Custom::Kanban::Board', foreign_key: :custom_kanban_board_id, inverse_of: :columns
  has_many :cards, class_name: 'Custom::Kanban::Card',
                   foreign_key: :custom_kanban_column_id, inverse_of: :column, dependent: :destroy

  validates :name, presence: true
  validates :custom_color, inclusion: { in: Custom::InboxCustomColor::PALETTE }, allow_nil: true

  default_scope { order(:position, :id) }
end
