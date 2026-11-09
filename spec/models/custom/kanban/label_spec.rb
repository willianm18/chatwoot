require 'rails_helper'

RSpec.describe Custom::Kanban::Label do
  let(:account) { create(:account) }
  let(:board) { Custom::Kanban::Board.create!(account: account, name: 'Fiscal') }

  it 'rejects a color outside the palette' do
    label = board.labels.new(name: 'Urgent', color: '#123456')
    expect(label).not_to be_valid
  end

  it 'attaches to a card through card_labels' do
    label = board.labels.create!(name: 'Urgent', color: described_class::PALETTE.first)
    column = board.columns.create!(name: 'To do', position: 0)
    card = column.cards.create!(title: 'x', position: 0)
    card.labels << label
    expect(card.reload.labels).to include(label)
  end
end
