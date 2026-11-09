# [fazer.ai fork] A per-board colored label (Trello-style). Palette is fixed.
class Custom::Kanban::Label < ApplicationRecord
  self.table_name = 'custom_kanban_labels'

  # Keep in sync with the frontend palette in
  # app/javascript/dashboard/routes/dashboard/kanban/constants.js.
  PALETTE = %w[
    #9F1239 #B91C1C #B45309 #15803D #0F766E
    #0E7490 #1D4ED8 #4338CA #6D28D9 #BE185D
  ].freeze

  belongs_to :board, class_name: 'Custom::Kanban::Board', foreign_key: :custom_kanban_board_id, inverse_of: :labels
  has_many :card_labels, class_name: 'Custom::Kanban::CardLabel',
                         foreign_key: :custom_kanban_label_id, inverse_of: :label, dependent: :destroy

  validates :name, presence: true
  validates :color, inclusion: { in: PALETTE }
end
