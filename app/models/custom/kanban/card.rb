# [fazer.ai fork] A task card inside a Kanban column, ordered by position.
class Custom::Kanban::Card < ApplicationRecord
  self.table_name = 'custom_kanban_cards'

  include Rails.application.routes.url_helpers

  belongs_to :column, class_name: 'Custom::Kanban::Column', foreign_key: :custom_kanban_column_id, inverse_of: :cards
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :card_labels, class_name: 'Custom::Kanban::CardLabel',
                         foreign_key: :custom_kanban_card_id, inverse_of: :card, dependent: :destroy
  has_many :labels, through: :card_labels
  has_many :card_assignees, class_name: 'Custom::Kanban::CardAssignee',
                            foreign_key: :custom_kanban_card_id, inverse_of: :card, dependent: :destroy
  has_many :assignees, through: :card_assignees, source: :user
  has_many :comments, class_name: 'Custom::Kanban::CardComment',
                      foreign_key: :custom_kanban_card_id, inverse_of: :card, dependent: :destroy
  has_many_attached :files

  FILE_SIZE_LIMIT = 40.megabytes

  validates :title, presence: true
  validate :files_within_size_limit
  validate :assignees_are_board_members

  default_scope { order(:position, :id) }

  delegate :board, to: :column

  def file_url(attachment)
    url_for(attachment)
  end

  private

  def files_within_size_limit
    files.each do |file|
      errors.add(:files, 'is too large') if file.blob.present? && file.blob.byte_size > FILE_SIZE_LIMIT
    end
  end

  def assignees_are_board_members
    member_ids = board.member_users.pluck(:id)
    errors.add(:assignees, 'must be board members') if assignees.any? { |user| member_ids.exclude?(user.id) }
  end
end
