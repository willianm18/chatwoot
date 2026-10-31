require 'rails_helper'

RSpec.describe 'Conversation Forwards API', type: :request do
  let!(:account) { create(:account) }
  let!(:channel) { create(:channel_whatsapp, account: account, provider: 'baileys', sync_templates: false, validate_provider_config: false) }
  let!(:inbox) { channel.inbox }
  let!(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'forward me') }
  let!(:target_contact) { create(:contact, account: account, phone_number: '+5511999990000') }

  describe 'POST /api/v1/accounts/{account.id}/conversations/<id>/forwards' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post api_v1_account_conversation_forwards_url(account_id: account.id, conversation_id: conversation.display_id)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user with access to conversation' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before { create(:inbox_member, inbox: inbox, user: agent) }

      it 'forwards the message to the target contact' do
        post api_v1_account_conversation_forwards_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { message_ids: [message.id], target_contact_id: target_contact.id },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        target_conversation = target_contact.conversations.last
        expect(target_conversation.messages.outgoing.last.content).to eq('forward me')
        expect(response.parsed_body['conversation_id']).to eq(target_conversation.display_id)
      end

      it 'returns 422 when the target contact has no phone number' do
        no_phone = create(:contact, account: account, phone_number: nil)

        post api_v1_account_conversation_forwards_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { message_ids: [message.id], target_contact_id: no_phone.id },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns 422 when a message cannot be forwarded' do
        note = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, private: true, content: 'note')

        post api_v1_account_conversation_forwards_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { message_ids: [note.id], target_contact_id: target_contact.id },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/<id>/forwards/contacts' do
    let(:agent) { create(:user, account: account, role: :agent) }

    before { create(:inbox_member, inbox: inbox, user: agent) }

    it 'returns only contacts with a thread on the source inbox matching the query' do
      on_inbox = create(:contact, account: account, name: 'Maria Souza', phone_number: '+5511911112222')
      create(:contact_inbox, contact: on_inbox, inbox: inbox, source_id: '5511911112222')
      other_inbox = create(:channel_whatsapp, account: account, provider: 'baileys', sync_templates: false,
                                              validate_provider_config: false).inbox
      off_inbox = create(:contact, account: account, name: 'Maria Lima', phone_number: '+5511933334444')
      create(:contact_inbox, contact: off_inbox, inbox: other_inbox, source_id: '5511933334444')

      get contacts_api_v1_account_conversation_forwards_url(account_id: account.id, conversation_id: conversation.display_id),
          params: { q: 'Maria' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      ids = response.parsed_body['payload'].map { |c| c['id'] }
      expect(ids).to contain_exactly(on_inbox.id)
    end

    it 'returns an empty payload for a blank query' do
      get contacts_api_v1_account_conversation_forwards_url(account_id: account.id, conversation_id: conversation.display_id),
          params: { q: '' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']).to eq([])
    end
  end
end
