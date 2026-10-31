import { isForwardableMessage } from '../isForwardableMessage.js';
import { MESSAGE_STATUS } from '../../constants';

describe('isForwardableMessage', () => {
  it('accepts a message with text', () => {
    expect(isForwardableMessage({ content: 'oi' })).toBe(true);
  });

  it('accepts a message with attachments but no text', () => {
    expect(
      isForwardableMessage({ content: '', attachments: [{ id: 1 }] })
    ).toBe(true);
  });

  it('rejects an empty message', () => {
    expect(isForwardableMessage({ content: '', attachments: [] })).toBe(false);
  });

  it('rejects private, reaction, deleted, failed and in-progress messages', () => {
    expect(isForwardableMessage({ content: 'x', private: true })).toBe(false);
    expect(
      isForwardableMessage({ content: 'x', contentAttributes: { isReaction: true } })
    ).toBe(false);
    expect(
      isForwardableMessage({ content: 'x', contentAttributes: { deleted: true } })
    ).toBe(false);
    expect(
      isForwardableMessage({ content: 'x', status: MESSAGE_STATUS.FAILED })
    ).toBe(false);
    expect(
      isForwardableMessage({ content: 'x', status: MESSAGE_STATUS.PROGRESS })
    ).toBe(false);
  });

  it('rejects a nullish message', () => {
    expect(isForwardableMessage(null)).toBe(false);
  });
});
