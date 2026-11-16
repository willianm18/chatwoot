require 'rails_helper'

RSpec.describe 'Conversation Custom Archive API', type: :request do
  let!(:account) { create(:account) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'POST /api/v1/accounts/:account_id/conversations/:conversation_id/custom_archive' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post api_v1_account_conversation_custom_archive_url(account_id: account.id, conversation_id: conversation.display_id)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent with access to the conversation' do
      it 'archives the conversation and broadcasts the update' do
        expect(Rails.configuration.dispatcher).to receive(:dispatch)
          .with('conversation.updated', anything, anything).at_least(:once)

        post api_v1_account_conversation_custom_archive_url(account_id: account.id, conversation_id: conversation.display_id),
             headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.custom_archived).to be(true)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/conversations/:conversation_id/custom_archive' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete api_v1_account_conversation_custom_archive_url(account_id: account.id, conversation_id: conversation.display_id)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent with access to the conversation' do
      it 'unarchives the conversation and broadcasts the update' do
        conversation.update!(custom_archived: true)

        expect(Rails.configuration.dispatcher).to receive(:dispatch)
          .with('conversation.updated', anything, anything).at_least(:once)

        delete api_v1_account_conversation_custom_archive_url(account_id: account.id, conversation_id: conversation.display_id),
               headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.custom_archived).to be(false)
      end
    end
  end
end
