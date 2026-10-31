<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useForwardSelection } from './useForwardSelection.js';
import ForwardSelectionBar from './ForwardSelectionBar.vue';
import ForwardWhatsappPanel from './ForwardWhatsappPanel.vue';

// [fazer.ai fork] Conversation-level host for the multi-select forward (Phase 2). Shows the
// action bar while a selection is active and opens the contact panel with the selected ids.
// Kept as its own component so ConversationView (Options API) only has to render one tag.
const props = defineProps({
  currentChat: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const { active, conversationId, selectedIds, count, clear } =
  useForwardSelection();

const panelOpen = ref(false);
const panelPosition = ref({ x: 0, y: 0 });

// The source content when exactly one message is selected; the panel falls back to a
// "{count} messages" summary for more than one.
const previewText = computed(() => {
  if (selectedIds.value.length !== 1) return '';
  const message = (props.currentChat?.messages || []).find(
    msg => msg.id === selectedIds.value[0]
  );
  if (!message) return '';
  if (message.content) return message.content;
  if (message.attachments?.length)
    return `📎 ${t('CONVERSATION.FORWARD.ATTACHMENT')}`;
  return '';
});

const onForward = event => {
  panelPosition.value = { x: event.clientX, y: event.clientY };
  panelOpen.value = true;
};

const onForwarded = () => {
  panelOpen.value = false;
  clear();
};
</script>

<template>
  <Teleport to="body">
    <div
      v-if="active"
      class="fixed left-1/2 -translate-x-1/2 bottom-24 z-[9998]"
    >
      <ForwardSelectionBar @forward="onForward" />
    </div>
  </Teleport>
  <ForwardWhatsappPanel
    v-if="panelOpen && count"
    :x="panelPosition.x"
    :y="panelPosition.y"
    :conversation-id="conversationId"
    :message-ids="selectedIds"
    :preview-text="previewText"
    @forwarded="onForwarded"
    @close="panelOpen = false"
  />
</template>
