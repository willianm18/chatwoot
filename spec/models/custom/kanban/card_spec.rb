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

    before { board.members.create!(user: member) }

    it 'has many assignees through the join table' do
      card = column.cards.create!(title: 'T', assignee_ids: [member.id])
      expect(card.assignees).to contain_exactly(member)
    end

    # Board-membership of assignees is enforced at the controller (the only write
    # path), not in the model: a model validation here would also run during the
    # position resequencing in #move and reject unrelated saves when a card still
    # carries an assignee who is no longer a member. See the cards controller spec.
    it 'does not reject a save when a card carries a non-member assignee' do
      outsider = create(:user, account: account)
      card = column.cards.create!(title: 'T', assignee_ids: [member.id])
      Custom::Kanban::CardAssignee.create!(card: card, user: outsider)
      card.reload.title = 'renamed'
      expect(card.save).to be(true)
    end
  end
end
