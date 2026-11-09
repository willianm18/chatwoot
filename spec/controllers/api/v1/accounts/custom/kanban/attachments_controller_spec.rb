require 'rails_helper'

RSpec.describe 'Kanban attachments API', type: :request do
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
  let(:file) { fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png') }

  it 'attaches a file uploaded by a member' do
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/attachments",
         params: { file: file }, headers: member.create_new_auth_token
    expect(response).to have_http_status(:success)
    expect(card.reload.files.count).to eq(1)
    expect(card.files.last.blob.metadata['uploaded_by']).to eq(member.id)
  end

  it 'forbids a non-uploader non-owner from removing' do
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/attachments",
         params: { file: file }, headers: member.create_new_auth_token
    attachment_id = card.reload.files.last.id
    stranger = create(:user, account: account, role: :agent)
    board.members.create!(user: stranger)
    delete "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/attachments/#{attachment_id}",
           headers: stranger.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
  end
end
