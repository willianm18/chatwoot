require 'rails_helper'

RSpec.describe Custom::Kanban::CardComment do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:board) { Custom::Kanban::Board.create!(account: account, name: 'Fiscal') }
  let(:column) { board.columns.create!(name: 'To do', position: 0) }
  let(:card) { column.cards.create!(title: 'x', position: 0) }

  it 'requires content' do
    comment = described_class.new(card: card, user: user)
    expect(comment).not_to be_valid
  end

  it 'is destroyed with its card' do
    card.comments.create!(user: user, content: 'hi')
    expect { card.destroy! }.to change(described_class, :count).by(-1)
  end

  it 'knows its author' do
    comment = card.comments.create!(user: user, content: 'hi')
    expect(comment.authored_by?(user)).to be(true)
  end
end
