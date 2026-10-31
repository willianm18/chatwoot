import camelcaseKeys from 'camelcase-keys';
import ConversationApi from 'dashboard/api/inbox/conversation';

const MIN_SEARCH_LENGTH = 2;

/**
 * [fazer.ai fork] Searches contacts reachable for a forward from the given conversation —
 * only the ones with a thread on the source inbox's own WhatsApp number. Mirrors
 * `createContactSearcher`: debounced upstream, abortable, and returns `null` on an aborted
 * request so callers can tell "cancelled" from "no results".
 *
 * @param {number|string} conversationId
 * @returns {(query: string) => Promise<Array|null>}
 */
export const createForwardableContactSearcher = conversationId => {
  let controller = null;

  return async query => {
    const trimmed = typeof query === 'string' ? query.trim() : '';

    controller?.abort();

    if (trimmed.length < MIN_SEARCH_LENGTH) return [];

    controller = new AbortController();

    try {
      const {
        data: { payload },
      } = await ConversationApi.forwardableContacts(conversationId, trimmed, {
        signal: controller.signal,
      });
      return camelcaseKeys(payload, { deep: true }) || [];
    } catch (error) {
      if (error?.name === 'AbortError' || error?.name === 'CanceledError') {
        return null;
      }
      throw error;
    }
  };
};
