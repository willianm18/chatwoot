<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { createForwardableContactSearcher } from './forwardContactSearch.js';

import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import Avatar from 'next/avatar/Avatar.vue';
import { useMessageContext } from '../provider.js';

defineProps({
  x: { type: Number, default: 0 },
  y: { type: Number, default: 0 },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const {
  id: messageId,
  content,
  attachments,
  conversationId,
} = useMessageContext();

const searchContacts = createForwardableContactSearcher(conversationId.value);
const contacts = ref([]);
const isSearching = ref(false);
const isForwarding = ref(false);
const query = ref('');

// A short, agent-facing summary of what will be forwarded.
const preview = computed(() => {
  if (content.value) return content.value;
  if (attachments.value?.length)
    return `📎 ${t('CONVERSATION.FORWARD.ATTACHMENT')}`;
  return '';
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
      conversationId: conversationId.value,
      messageIds: [messageId.value],
      targetContactId: contact.id,
    });
    useAlert(t('CONVERSATION.FORWARD.SUCCESS'));
    emit('close');
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
