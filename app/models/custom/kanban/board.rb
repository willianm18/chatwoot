# [fazer.ai fork] Native team-tasks Kanban. See docs/superpowers/specs/2026-11-09-kanban-team-tasks-design.md
class Custom::Kanban::Board < ApplicationRecord
  self.table_name = 'custom_kanban_boards'

  DEFAULT_COLUMN_KEYS = %w[to_do doing done].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :members, class_name: 'Custom::Kanban::BoardMember',
                     foreign_key: :custom_kanban_board_id, inverse_of: :board, dependent: :destroy
  has_many :member_users, through: :members, source: :user
  has_many :columns, class_name: 'Custom::Kanban::Column',
                     foreign_key: :custom_kanban_board_id, inverse_of: :board, dependent: :destroy
  has_many :labels, class_name: 'Custom::Kanban::Label',
                    foreign_key: :custom_kanban_board_id, inverse_of: :board, dependent: :destroy

  validates :name, presence: true

  # A user can access a board only when they are a member of it. The account role
  # (administrator/agent) does not grant visibility — boards are private to their
  # members (see docs/superpowers/specs/2026-11-10-kanban-private-boards-design.md).
  scope :accessible_by, lambda { |account_user|
    where(account_id: account_user.account_id)
      .joins(:members)
      .where(custom_kanban_board_members: { user_id: account_user.user_id })
      .distinct
  }

  def owned_by?(user)
    created_by_id == user.id
  end

  # Seed the three starter columns on a brand new board (editable afterwards).
  def default_columns!
    DEFAULT_COLUMN_KEYS.each_with_index do |key, index|
      columns.create!(name: I18n.t("kanban.default_columns.#{key}", default: key.humanize), position: index)
    end
  end
end
