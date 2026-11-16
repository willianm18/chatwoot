import actions from '../actions';
import ConversationApi from '../../../../api/inbox/conversation';

vi.mock('../../../../api/inbox/conversation', () => ({
  default: {
    archive: vi.fn(),
    unarchive: vi.fn(),
  },
}));

describe('#toggleConversationArchived', () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  it('archives and dispatches updateConversation with the response', async () => {
    const conversation = { id: 1, custom_archived: true };
    ConversationApi.archive.mockResolvedValue({ data: conversation });
    const commit = vi.fn();
    const dispatch = vi.fn();

    await actions.toggleConversationArchived(
      { commit, dispatch },
      { conversationId: 1, archived: true }
    );

    expect(dispatch).toHaveBeenCalledWith('updateConversation', conversation);
  });

  it('unarchives and dispatches updateConversation with the response', async () => {
    const conversation = { id: 1, custom_archived: false };
    ConversationApi.unarchive.mockResolvedValue({ data: conversation });
    const commit = vi.fn();
    const dispatch = vi.fn();

    await actions.toggleConversationArchived(
      { commit, dispatch },
      { conversationId: 1, archived: false }
    );

    expect(ConversationApi.unarchive).toHaveBeenCalledWith(1);
    expect(dispatch).toHaveBeenCalledWith('updateConversation', conversation);
  });
});
