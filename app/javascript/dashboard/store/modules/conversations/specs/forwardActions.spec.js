import actions from '../actions';
import ConversationApi from '../../../../api/inbox/conversation';

vi.mock('../../../../api/inbox/conversation', () => ({
  default: {
    forwardMessages: vi.fn(),
  },
}));

describe('conversations/actions forwardMessages', () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  it('calls the forward API with the conversation, message ids and target contact', async () => {
    ConversationApi.forwardMessages.mockResolvedValue({
      data: { conversation_id: 42 },
    });

    await actions.forwardMessages(
      {},
      { conversationId: 7, messageIds: [1, 2], targetContactId: 99 }
    );

    expect(ConversationApi.forwardMessages).toHaveBeenCalledWith(7, {
      messageIds: [1, 2],
      targetContactId: 99,
    });
  });

  it('propagates API errors', async () => {
    ConversationApi.forwardMessages.mockRejectedValue(new Error('boom'));

    await expect(
      actions.forwardMessages(
        {},
        { conversationId: 7, messageIds: [1], targetContactId: 99 }
      )
    ).rejects.toThrow('boom');
  });
});
