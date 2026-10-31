require 'rails_helper'

RSpec.describe Custom::Messages::ForwardService do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) { create(:channel_whatsapp, account: account, provider: 'baileys', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { channel.inbox }
  let(:source_contact) { create(:contact, account: account, phone_number: '+5511988887777') }
  let(:source_contact_inbox) { create(:contact_inbox, contact: source_contact, inbox: inbox, source_id: '5511988887777') }
  let(:source_conversation) { create(:conversation, account: account, inbox: inbox, contact: source_contact, contact_inbox: source_contact_inbox) }
  let(:target_contact) { create(:contact, account: account, phone_number: '+5511999990000') }

  def forward(message_ids)
    described_class.new(
      conversation: source_conversation,
      message_ids: message_ids,
      target_contact: target_contact,
      user: agent
    ).perform
  end

  describe '#perform' do
    it 'forwards a text message as a new outgoing message in the target contact conversation' do
      message = create(:message, account: account, inbox: inbox, conversation: source_conversation,
                                 message_type: :incoming, content: 'Comprovante em anexo')

      target = forward([message.id])

      expect(target.contact).to eq(target_contact)
      expect(target.inbox).to eq(inbox)
      forwarded = target.messages.outgoing.last
      expect(forwarded.content).to eq('Comprovante em anexo')
      expect(forwarded.content_attributes['forwarded']).to be(true)
    end

    it 'forwards attachments reusing the same blob (no re-upload)' do
      message = create(:message, account: account, inbox: inbox, conversation: source_conversation,
                                 message_type: :incoming, content: '')
      attachment = message.attachments.new(account_id: account.id, file_type: :image)
      attachment.file.attach(io: Rails.root.join('spec/assets/sample.png').open, filename: 'sample.png', content_type: 'image/png')
      attachment.save!

      target = forward([message.id])

      forwarded = target.messages.outgoing.last
      expect(forwarded.attachments.count).to eq(1)
      expect(forwarded.attachments.first.file.blob).to eq(attachment.file.blob)
    end

    it 'reuses an existing conversation with the target contact' do
      existing_ci = create(:contact_inbox, contact: target_contact, inbox: inbox, source_id: '5511999990000')
      existing_conversation = create(:conversation, account: account, inbox: inbox, contact: target_contact, contact_inbox: existing_ci)
      message = create(:message, account: account, inbox: inbox, conversation: source_conversation,
                                 message_type: :incoming, content: 'oi')

      target = forward([message.id])

      expect(target.id).to eq(existing_conversation.id)
    end

    it 'preserves the order of the forwarded messages' do
      first = create(:message, account: account, inbox: inbox, conversation: source_conversation, message_type: :incoming, content: 'um')
      second = create(:message, account: account, inbox: inbox, conversation: source_conversation, message_type: :incoming, content: 'dois')

      target = forward([first.id, second.id])

      contents = target.messages.outgoing.order(:created_at).pluck(:content)
      expect(contents).to eq(%w[um dois])
    end

    it 'refuses a non-session WhatsApp inbox' do
      cloud_channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
      cloud_conversation = create(:conversation, account: account, inbox: cloud_channel.inbox)
      message = create(:message, account: account, inbox: cloud_channel.inbox, conversation: cloud_conversation, content: 'x')

      expect do
        described_class.new(conversation: cloud_conversation, message_ids: [message.id], target_contact: target_contact, user: agent).perform
      end.to raise_error(ArgumentError, /native WhatsApp/)
    end

    it 'refuses a private note' do
      message = create(:message, account: account, inbox: inbox, conversation: source_conversation,
                                 message_type: :outgoing, private: true, content: 'nota interna')

      expect { forward([message.id]) }.to raise_error(ArgumentError, /cannot be forwarded/)
    end

    it 'refuses a deleted message' do
      message = create(:message, account: account, inbox: inbox, conversation: source_conversation,
                                 message_type: :incoming, content: 'x', content_attributes: { deleted: true })

      expect { forward([message.id]) }.to raise_error(ArgumentError, /cannot be forwarded/)
    end
  end
end
