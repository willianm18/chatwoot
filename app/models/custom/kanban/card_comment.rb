# [fazer.ai fork] A plain-text comment on a Kanban card (phase 2).
class Custom::Kanban::CardComment < ApplicationRecord
  self.table_name = 'custom_kanban_card_comments'

  belongs_to :card, class_name: 'Custom::Kanban::Card', foreign_key: :custom_kanban_card_id, inverse_of: :comments
  belongs_to :user

  validates :content, presence: true

  default_scope { order(:created_at, :id) }

  def authored_by?(a_user)
    user_id == a_user.id
  end
end
