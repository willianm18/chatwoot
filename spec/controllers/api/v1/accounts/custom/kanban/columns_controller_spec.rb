require 'rails_helper'

RSpec.describe 'Kanban columns API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b
  end

  it 'creates a column at the end' do
    board.columns.create!(name: 'To do', position: 0)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/columns",
         params: { column: { name: 'Doing' } }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(board.columns.last.position).to eq(1)
  end

  it 'reorders columns by the given id order' do
    c1 = board.columns.create!(name: 'A', position: 0)
    c2 = board.columns.create!(name: 'B', position: 1)
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/columns/reorder",
          params: { column_ids: [c2.id, c1.id] }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(c1.reload.position).to eq(1)
    expect(c2.reload.position).to eq(0)
  end
end
