# Forwards one or more messages from a native WhatsApp conversation to another contact,
# re-sending the content (and media) through the normal outgoing pipeline. There is no
# "forwarded" marker on the current connector, so this re-sends the content as the backlog
# anticipated for the Cloud API.
#
# Accepts a list of message ids from the start so the Phase 2 multi-select UI needs no
# backend change — it only has to send more ids.
module Custom
  module Messages
    class ForwardService
      pattr_initialize [:conversation!, :message_ids!, :target_contact!, :user!]

      FORWARDABLE_FILE_TYPES = %w[image audio video file].freeze

      def perform
        validate_source_inbox!
        validate_target_contact!
        messages = load_forwardable_messages!
        target_conversation = resolve_target_conversation!
        messages.each { |message| forward(message, target_conversation) }
        target_conversation
      end

      private

      def source_inbox
        @source_inbox ||= conversation.inbox
      end

      def validate_source_inbox!
        channel = source_inbox.channel
        return if channel.is_a?(Channel::Whatsapp) && (channel.session_provider? || channel.provider == 'baileys')

        raise ArgumentError, 'Forwarding is only available on native WhatsApp inboxes'
      end

      # A native WhatsApp contact is addressed by phone number; without one there is no
      # source_id to open a conversation with.
      def validate_target_contact!
        raise ArgumentError, 'This contact has no phone number' if target_contact.phone_number.blank?
      end

      # Keeps the order the caller listed, and refuses the whole request if any id is not
      # forwardable — a partial forward is worse than an error the agent can act on.
      def load_forwardable_messages!
        messages = conversation.messages.where(id: message_ids).index_by(&:id)
        message_ids.map do |id|
          message = messages[id.to_i]
          raise ArgumentError, "Message #{id} is not in this conversation" if message.blank?
          raise ArgumentError, "Message #{id} cannot be forwarded" unless forwardable?(message)

          message
        end
      end

      def forwardable?(message)
        return false if message.private?
        return false if message.reaction?
        return false if message.content_attributes['deleted']
        return false if message.content_attributes['is_unsupported']
        return false unless message.incoming? || message.outgoing?

        message.content.present? || copyable_attachments(message).any?
      end

      def copyable_attachments(message)
        message.attachments.select { |attachment| FORWARDABLE_FILE_TYPES.include?(attachment.file_type) }
      end

      def resolve_target_conversation!
        contact_inbox = ::ContactInboxWithContactBuilder.new(
          inbox: source_inbox,
          contact_attributes: {
            name: target_contact.name,
            phone_number: target_contact.phone_number,
            identifier: target_contact.identifier,
            email: target_contact.email
          }.compact
        ).perform
        raise ArgumentError, 'Could not resolve a WhatsApp contact for the target' if contact_inbox.blank?

        # WhatsApp is one chat per contact, so the forward lands in the contact's existing
        # conversation when there is one and only opens a new one otherwise.
        contact_inbox.conversations.order(:created_at).last ||
          ::ConversationBuilder.new(params: {}, contact_inbox: contact_inbox).perform
      end

      def forward(message, target_conversation)
        ::Messages::MessageBuilder.new(user, target_conversation, build_params(message)).perform
      end

      def build_params(message)
        {
          message_type: 'outgoing',
          content: message.content,
          attachments: copyable_attachments(message).map { |attachment| attachment.file.blob },
          content_attributes: { forwarded: true }
        }.with_indifferent_access
      end
    end
  end
end
