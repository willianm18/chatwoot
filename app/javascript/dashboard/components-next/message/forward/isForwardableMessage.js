import { MESSAGE_STATUS } from '../constants';

// [fazer.ai fork] The per-message half of the forward gate, shared by the context-menu option
// and the multi-select checkboxes so the rule lives in one place. The inbox-level half (native
// WhatsApp session inbox) stays with each caller, since it does not depend on the message.
//
// Accepts a message-shaped object with camelCase keys: `private`, `status`, `content`,
// `attachments`, and `contentAttributes` ({ isReaction, deleted }).
export const isForwardableMessage = message => {
  if (!message) return false;
  if (message.private) return false;
  if (message.contentAttributes?.isReaction) return false;
  if (message.contentAttributes?.deleted) return false;
  if (
    message.status === MESSAGE_STATUS.FAILED ||
    message.status === MESSAGE_STATUS.PROGRESS
  ) {
    return false;
  }

  const hasText = !!message.content;
  const hasAttachments = !!(message.attachments && message.attachments.length);
  return hasText || hasAttachments;
};
