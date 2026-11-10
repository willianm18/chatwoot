require 'rails_helper'

RSpec.describe 'Kanban real-time broadcast', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:member) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b.members.create!(user: member)
    b
  end
  let!(:column) { board.columns.create!(name: 'To do', position: 0) }

  it 'broadcasts kanban.board.updated to member tokens after a mutation' do
    expect(ActionCableBroadcastJob).to receive(:perform_later) do |tokens, event, data|
      expect(event).to eq('kanban.board.updated')
      expect(data).to eq({ board_id: board.id, account_id: account.id })
      expect(tokens).to contain_exactly(owner.pubsub_token, member.pubsub_token)
    end
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
         params: { card: { column_id: column.id, title: 'new' } }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
  end

  it 'also broadcasts to account administrators who are not members' do
    admin = create(:user, account: account, role: :administrator)
    received = nil
    allow(ActionCableBroadcastJob).to receive(:perform_later) { |tokens, _event, _data| received = tokens }
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
         params: { card: { column_id: column.id, title: 'new' } }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(received).to include(admin.pubsub_token)
  end

  it 'does not broadcast on a failed (404) request' do
    expect(ActionCableBroadcastJob).not_to receive(:perform_later)
    other = create(:user, account: account, role: :agent)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
         params: { card: { column_id: column.id, title: 'x' } }, headers: other.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
