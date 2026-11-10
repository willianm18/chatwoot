require 'rails_helper'

RSpec.describe Custom::Kanban::Card do
  let(:account) { create(:account) }
  let(:board) { Custom::Kanban::Board.create!(account: account, name: 'Fiscal') }
  let(:column) { board.columns.create!(name: 'To do', position: 0) }

  it 'requires a title' do
    card = described_class.new(column: column)
    expect(card).not_to be_valid
    expect(card.errors[:title]).to be_present
  end

  it 'orders cards by position' do
    c2 = column.cards.create!(title: 'second', position: 1)
    c1 = column.cards.create!(title: 'first', position: 0)
    expect(column.cards.to_a).to eq([c1, c2])
  end

  it 'reaches the board through its column' do
    card = column.cards.create!(title: 'x', position: 0)
    expect(card.board).to eq(board)
  end

  describe 'assignees' do
    let(:member) { create(:user, account: account) }
    let(:outsider) { create(:user, account: account) }

    before { board.members.create!(user: member) }

    it 'accepts assignees who are board members' do
      card = column.cards.create!(title: 'T', assignee_ids: [member.id])
      expect(card.assignees).to contain_exactly(member)
    end

    it 'rejects an assignee who is not a board member' do
      card = column.cards.new(title: 'T', assignee_ids: [outsider.id])
      expect(card).not_to be_valid
      expect(card.errors[:assignees]).to be_present
    end
  end
end
