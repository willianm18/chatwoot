import { reactive, computed } from 'vue';

// [fazer.ai fork] Shared selection state for the WhatsApp multi-select forward (Phase 2).
// Ephemeral UI state scoped to the open conversation — no Vuex. Module-level so the message
// bubbles (deep in the tree) and the action bar (at the conversation level) read and write the
// same selection. Switching conversations does not drag the selection along: `isActiveFor`
// only answers true for the conversation that started it.
const state = reactive({
  active: false,
  conversationId: null,
  ids: new Set(),
});

const start = (messageId, conversationId) => {
  if (state.conversationId !== conversationId) state.ids = new Set();
  state.active = true;
  state.conversationId = conversationId;
  state.ids.add(messageId);
};

const toggle = messageId => {
  if (state.ids.has(messageId)) state.ids.delete(messageId);
  else state.ids.add(messageId);
};

const clear = () => {
  state.active = false;
  state.conversationId = null;
  state.ids = new Set();
};

export const useForwardSelection = () => ({
  start,
  toggle,
  clear,
  isSelected: messageId => state.ids.has(messageId),
  isActiveFor: conversationId =>
    state.active && state.conversationId === conversationId,
  active: computed(() => state.active),
  conversationId: computed(() => state.conversationId),
  count: computed(() => state.ids.size),
  selectedIds: computed(() => Array.from(state.ids)),
});
