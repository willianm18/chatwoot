<script setup>
import { onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useForwardSelection } from './useForwardSelection.js';

// [fazer.ai fork] Action bar for the WhatsApp multi-select forward (Phase 2). Shown at the
// conversation level while a selection is active; the parent opens the contact panel on
// `forward`. Esc cancels, matching the panel's own dismissal.
const emit = defineEmits(['forward']);

const { t } = useI18n();
const { count, clear } = useForwardSelection();

const onForward = event => {
  if (!count.value) return;
  emit('forward', event);
};

const onKeydown = e => {
  if (e.key === 'Escape') clear();
};

onMounted(() => document.addEventListener('keydown', onKeydown));
onBeforeUnmount(() => document.removeEventListener('keydown', onKeydown));
</script>

<template>
  <div
    class="flex items-center gap-3 px-4 py-2 bg-n-solid-2 border border-n-strong rounded-xl shadow-sm"
  >
    <button
      type="button"
      class="text-sm text-n-slate-11 hover:text-n-slate-12"
      @click="clear"
    >
      {{ t('CONVERSATION.FORWARD.CANCEL') }}
    </button>
    <span class="flex-1 text-sm font-medium text-n-slate-12 text-center">
      {{ t('CONVERSATION.FORWARD.SELECTION_COUNT', { count }) }}
    </span>
    <button
      type="button"
      class="text-sm font-medium text-n-brand hover:underline disabled:opacity-50"
      :disabled="!count"
      @click="onForward"
    >
      {{ t('CONVERSATION.FORWARD.SEND') }}
    </button>
  </div>
</template>
