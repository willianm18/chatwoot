require 'rails_helper'

RSpec.describe 'Kanban boards API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  def create_board(creator)
    board = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: creator.id)
    board.members.create!(user: creator)
    board
  end

  describe 'POST /api/v1/accounts/:account_id/custom/kanban/boards' do
    it 'creates a board, adds the creator as member and seeds columns' do
      expect do
        post "/api/v1/accounts/#{account.id}/custom/kanban/boards",
             params: { board: { name: 'Contábil' } }, headers: owner.create_new_auth_token, as: :json
      end.to change(Custom::Kanban::Board, :count).by(1)
      expect(response).to have_http_status(:success)
      board = Custom::Kanban::Board.last
      expect(board.member_users).to include(owner)
      expect(board.columns.count).to eq(3)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/custom/kanban/boards' do
    it 'lists only boards the user can access' do
      mine = create_board(owner)
      create_board(outsider)
      get "/api/v1/accounts/#{account.id}/custom/kanban/boards", headers: owner.create_new_auth_token, as: :json
      ids = response.parsed_body['payload'].map { |b| b['id'] }
      expect(ids).to contain_exactly(mine.id)
    end

    it 'lists every board for an administrator' do
      a = create_board(owner)
      b = create_board(outsider)
      get "/api/v1/accounts/#{account.id}/custom/kanban/boards", headers: admin.create_new_auth_token, as: :json
      ids = response.parsed_body['payload'].map { |x| x['id'] }
      expect(ids).to include(a.id, b.id)
    end
  end

  describe 'GET show' do
    it 'returns 404 for a board the user cannot access' do
      board = create_board(outsider)
      get "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}", headers: owner.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE destroy' do
    it 'forbids a non-owner member from deleting' do
      board = create_board(owner)
      board.members.create!(user: outsider)
      delete "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}",
             headers: outsider.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
