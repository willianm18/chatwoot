require 'rails_helper'

RSpec.describe 'Kanban members API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:stranger) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b
  end

  it 'lets the owner add a member' do
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/members",
         params: { user_id: member.id }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(board.member_users).to include(member)
  end

  it 'forbids a non-owner member from adding members' do
    board.members.create!(user: member)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/members",
         params: { user_id: stranger.id }, headers: member.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end
end
