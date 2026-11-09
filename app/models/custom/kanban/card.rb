# [fazer.ai fork] A task card inside a Kanban column, ordered by position.
class Custom::Kanban::Card < ApplicationRecord
  self.table_name = 'custom_kanban_cards'

  belongs_to :column, class_name: 'Custom::Kanban::Column', foreign_key: :custom_kanban_column_id, inverse_of: :cards
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :card_labels, class_name: 'Custom::Kanban::CardLabel',
                         foreign_key: :custom_kanban_card_id, inverse_of: :card, dependent: :destroy
  has_many :labels, through: :card_labels

  validates :title, presence: true

  default_scope { order(:position, :id) }

  delegate :board, to: :column
end
