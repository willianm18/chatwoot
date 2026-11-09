# [fazer.ai fork] Join between a Kanban card and a board label.
class Custom::Kanban::CardLabel < ApplicationRecord
  self.table_name = 'custom_kanban_card_labels'

  belongs_to :card, class_name: 'Custom::Kanban::Card', foreign_key: :custom_kanban_card_id, inverse_of: :card_labels
  belongs_to :label, class_name: 'Custom::Kanban::Label', foreign_key: :custom_kanban_label_id, inverse_of: :card_labels

  validates :custom_kanban_label_id, uniqueness: { scope: :custom_kanban_card_id }
end
