require 'rails_helper'

RSpec.describe 'Kanban comments API', type: :request do
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
  let!(:card) { column.cards.create!(title: 'x', position: 0) }

  it 'lets a member add a comment' do
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/comments",
         params: { content: 'hello' }, headers: member.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(card.comments.last.user).to eq(member)
  end

  it 'forbids editing another user comment (non-owner)' do
    comment = card.comments.create!(user: owner, content: 'orig')
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/comments/#{comment.id}",
          params: { content: 'edit' }, headers: member.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'lets the board owner delete any comment' do
    comment = card.comments.create!(user: member, content: 'm')
    delete "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/comments/#{comment.id}",
           headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(card.comments.count).to eq(0)
  end
end
