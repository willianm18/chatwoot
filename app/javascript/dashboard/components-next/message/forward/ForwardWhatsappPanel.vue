<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { createForwardableContactSearcher } from './forwardContactSearch.js';
import { useForwardSelection } from './useForwardSelection.js';

import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import Avatar from 'next/avatar/Avatar.vue';

// [fazer.ai fork] Phase 2 opens this panel at the conversation level from the selection bar,
// so the message set comes in as props (a list of ids) rather than from the single-message
// context. `previewText` is the source message's content when exactly one is selected.
const props = defineProps({
  x: { type: Number, default: 0 },
  y: { type: Number, default: 0 },
  conversationId: { type: Number, required: true },
  messageIds: { type: Array, required: true },
  previewText: { type: String, default: '' },
});

// `forwarded` lets the caller close the panel UI; `close` also fires on dismiss, which must
// keep the selection for a retry.
const emit = defineEmits(['close', 'forwarded']);

const { t } = useI18n();
const store = useStore();
const { clear } = useForwardSelection();

const searchContacts = createForwardableContactSearcher(props.conversationId);
const contacts = ref([]);
const isSearching = ref(false);
const isForwarding = ref(false);
const query = ref('');

// A short, agent-facing summary of what will be forwarded.
const preview = computed(() => {
  if (props.messageIds.length > 1)
    return t('CONVERSATION.FORWARD.N_MESSAGES', {
      count: props.messageIds.length,
    });
  return props.previewText;
});

const onSearch = debounce(async value => {
  query.value = value;
  const trimmed = value.trim();
  if (trimmed.length < 2) {
    contacts.value = [];
    return;
  }
  isSearching.value = true;
  try {
    const results = await searchContacts(trimmed);
    if (results === null) return;
    contacts.value = results;
  } catch (error) {
    useAlert(t('CONVERSATION.FORWARD.ERROR'));
  } finally {
    isSearching.value = false;
  }
}, 400);

const selectContact = async contact => {
  if (isForwarding.value) return;
  if (!contact.phoneNumber) {
    useAlert(t('CONVERSATION.FORWARD.NO_PHONE'));
    return;
  }
  isForwarding.value = true;
  try {
    await store.dispatch('forwardMessages', {
      conversationId: props.conversationId,
      messageIds: props.messageIds,
      targetContactId: contact.id,
    });
    useAlert(t('CONVERSATION.FORWARD.SUCCESS'));
    // Clear here, not via the emit: a forward dispatched just as the panel is dismissed would
    // resolve on an unmounted panel and the `forwarded` listener would already be gone, leaving
    // the bubbles checked. `clear()` is a plain store call, so it runs regardless.
    clear();
    emit('forwarded');
  } catch (error) {
    useAlert(t('CONVERSATION.FORWARD.ERROR'));
  } finally {
    isForwarding.value = false;
  }
};
</script>

<template>
  <ContextMenu :x="x" :y="y" @close="emit('close')">
    <div
      class="flex flex-col w-80 max-h-[26rem] overflow-hidden bg-n-alpha-3 border border-n-strong shadow-sm backdrop-blur-[100px] rounded-xl cursor-default"
    >
      <div class="px-4 pt-3 pb-2 border-b border-n-strong">
        <p class="text-sm font-medium text-n-slate-12 mb-1">
          {{ t('CONVERSATION.FORWARD.TITLE') }}
        </p>
        <p v-if="preview" class="text-xs text-n-slate-11 truncate">
          {{ preview }}
        </p>
      </div>
      <div class="px-4 py-2 border-b border-n-strong">
        <input
          :value="query"
          type="text"
          class="w-full text-sm bg-transparent outline-none text-n-slate-12 placeholder:text-n-slate-10"
          :placeholder="t('CONVERSATION.FORWARD.SEARCH_PLACEHOLDER')"
          @input="onSearch($event.target.value)"
        />
      </div>
      <div class="flex-1 overflow-y-auto py-1">
        <p
          v-if="
            !isSearching && query.trim().length >= 2 && contacts.length === 0
          "
          class="px-4 py-3 text-xs text-n-slate-11"
        >
          {{ t('CONVERSATION.FORWARD.EMPTY') }}
        </p>
        <button
          v-for="contact in contacts"
          :key="contact.id"
          type="button"
          class="flex items-center w-full gap-2 px-4 py-2 text-start hover:bg-n-alpha-1 disabled:opacity-50"
          :disabled="isForwarding"
          @click="selectContact(contact)"
        >
          <Avatar :name="contact.name" :src="contact.thumbnail" :size="24" />
          <span class="flex flex-col min-w-0">
            <span class="text-sm text-n-slate-12 truncate">{{
              contact.name
            }}</span>
            <span class="text-xs text-n-slate-11 truncate">
              {{ contact.phoneNumber || contact.email }}
            </span>
          </span>
        </button>
      </div>
    </div>
  </ContextMenu>
</template>
