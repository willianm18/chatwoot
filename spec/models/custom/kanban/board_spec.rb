require 'rails_helper'

RSpec.describe Custom::Kanban::Board do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  def account_user_for(user)
    account.account_users.find_by(user: user)
  end

  def build_board(creator)
    board = described_class.create!(account: account, name: 'Fiscal', created_by_id: creator.id)
    board.members.create!(user: creator)
    board
  end

  describe '.accessible_by' do
    it 'includes boards the user is a member of' do
      board = build_board(owner)
      board.members.create!(user: member)
      expect(described_class.accessible_by(account_user_for(member))).to include(board)
    end

    it 'excludes boards the user is not a member of' do
      board = build_board(owner)
      expect(described_class.accessible_by(account_user_for(outsider))).not_to include(board)
    end

    it 'includes every account board for an administrator' do
      board = build_board(owner)
      expect(described_class.accessible_by(account_user_for(admin))).to include(board)
    end
  end

  describe '#owned_by?' do
    it 'is true only for the creator' do
      board = build_board(owner)
      expect(board.owned_by?(owner)).to be(true)
      expect(board.owned_by?(member)).to be(false)
    end
  end

  describe '#default_columns!' do
    it 'seeds three ordered columns' do
      board = build_board(owner)
      board.default_columns!
      expect(board.columns.pluck(:position)).to eq([0, 1, 2])
    end
  end
end
