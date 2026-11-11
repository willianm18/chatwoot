require 'rails_helper'

RSpec.describe 'Kanban cards API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b
  end
  let!(:todo) { board.columns.create!(name: 'To do', position: 0) }
  let!(:doing) { board.columns.create!(name: 'Doing', position: 1) }

  it 'creates a card at the end of its column' do
    todo.cards.create!(title: 'first', position: 0)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
         params: { card: { column_id: todo.id, title: 'second' } }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(todo.cards.last.position).to eq(1)
  end

  it 'moves a card to another column and resequences' do
    c = todo.cards.create!(title: 'x', position: 0)
    doing.cards.create!(title: 'a', position: 0)
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{c.id}/move",
          params: { column_id: doing.id, position: 0 }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(c.reload.column).to eq(doing)
    expect(c.reload.position).to eq(0)
    expect(doing.cards.pluck(:position)).to eq([0, 1])
  end

  it 'clamps an out-of-range move position to the end of the column' do
    doing.cards.create!(title: 'a', position: 0)
    c = todo.cards.create!(title: 'x', position: 0)
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{c.id}/move",
          params: { column_id: doing.id, position: 999 }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(doing.cards.pluck(:position)).to eq([0, 1])
    expect(c.reload.position).to eq(1)
  end

  it 'moves a card even when a sibling still carries a non-member assignee' do
    # Regression: #move resequences the whole column with update!; a model-level
    # assignee-membership validation would make that fail with 422 for any column
    # holding a card whose assignee is no longer a member, silently breaking the
    # move and its real-time broadcast.
    outsider = create(:user, account: account, role: :agent)
    sibling = doing.cards.create!(title: 'sibling', position: 0)
    Custom::Kanban::CardAssignee.create!(card: sibling, user: outsider)
    moving = todo.cards.create!(title: 'moving', position: 0)
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{moving.id}/move",
          params: { column_id: doing.id, position: 0 }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(moving.reload.column).to eq(doing)
  end

  it 'includes the attachment byte size in the payload' do
    card = todo.cards.create!(title: 'x', position: 0)
    card.files.attach(
      io: StringIO.new('hello'), filename: 'a.txt', content_type: 'text/plain'
    )
    get "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}",
        headers: owner.create_new_auth_token, as: :json
    returned = response.parsed_body['columns'].flat_map { |c| c['cards'] }.find { |c| c['id'] == card.id }
    expect(returned['attachments'].first['byte_size']).to eq(5)
  end

  it 'returns 404 moving a card on a board the user cannot access' do
    other = create(:user, account: account, role: :agent)
    c = todo.cards.create!(title: 'x', position: 0)
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{c.id}/move",
          params: { column_id: doing.id, position: 0 }, headers: other.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'assigns multiple board members to a card' do
    member = create(:user, account: account, role: :agent)
    board.members.create!(user: member)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
         params: { card: { column_id: todo.id, title: 'x', assignee_ids: [owner.id, member.id] } },
         headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['assignee_ids']).to contain_exactly(owner.id, member.id)
  end

  it 'rejects an assignee who is not a board member' do
    outsider = create(:user, account: account, role: :agent)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
         params: { card: { column_id: todo.id, title: 'x', assignee_ids: [outsider.id] } },
         headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'returns assignee_ids on the card and members on the board' do
    member = create(:user, account: account, role: :agent)
    board.members.create!(user: member)
    card = todo.cards.create!(title: 'x', position: 0, assignee_ids: [member.id])
    get "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}",
        headers: owner.create_new_auth_token, as: :json
    body = response.parsed_body
    expect(body['members'].map { |m| m['user_id'] }).to include(member.id)
    returned = body['columns'].flat_map { |c| c['cards'] }.find { |c| c['id'] == card.id }
    expect(returned['assignee_ids']).to include(member.id)
  end
end
