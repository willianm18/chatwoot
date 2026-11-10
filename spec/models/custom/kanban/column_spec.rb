require 'rails_helper'

RSpec.describe Custom::Kanban::Column do
  let(:account) { create(:account) }
  let(:board) { Custom::Kanban::Board.create!(account: account, name: 'B') }

  it 'accepts a color from the palette' do
    column = board.columns.new(name: 'To do', custom_color: Custom::InboxCustomColor::PALETTE.first)
    expect(column).to be_valid
  end

  it 'accepts a nil color' do
    expect(board.columns.new(name: 'To do', custom_color: nil)).to be_valid
  end

  it 'rejects a color outside the palette' do
    column = board.columns.new(name: 'To do', custom_color: '#123456')
    expect(column).not_to be_valid
    expect(column.errors[:custom_color]).to be_present
  end
end
