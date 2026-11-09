<script setup>
import { ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  card: { type: Object, required: true },
});

const store = useStore();
const { t } = useI18n();
const fileInput = ref(null);

const onPick = async event => {
  const [file] = event.target.files;
  if (!file) return;
  await store.dispatch('kanban/addAttachment', {
    boardId: props.boardId,
    cardId: props.card.id,
    file,
  });
  if (fileInput.value) fileInput.value.value = '';
};

const remove = attachment =>
  store.dispatch('kanban/removeAttachment', {
    boardId: props.boardId,
    cardId: props.card.id,
    id: attachment.id,
  });
</script>

<template>
  <div class="flex flex-col gap-2">
    <h4 class="text-sm font-medium text-n-slate-12">
      {{ t('KANBAN.ATTACHMENTS.TITLE') }}
    </h4>
    <ul v-if="card.attachments?.length" class="flex flex-col gap-2">
      <li
        v-for="attachment in card.attachments"
        :key="attachment.id"
        class="flex items-center gap-2"
      >
        <img
          v-if="attachment.is_image"
          :src="attachment.file_url"
          :alt="attachment.filename"
          class="object-cover rounded size-10"
        />
        <Icon v-else icon="i-lucide-file" class="size-5 text-n-slate-11" />
        <a
          :href="attachment.file_url"
          target="_blank"
          rel="noopener noreferrer"
          class="flex-1 text-sm truncate text-n-brand"
        >
          {{ attachment.filename }}
        </a>
        <button class="text-xs text-n-ruby-11" @click="remove(attachment)">
          {{ t('KANBAN.ATTACHMENTS.REMOVE') }}
        </button>
      </li>
    </ul>
    <p v-else class="text-xs text-n-slate-10">
      {{ t('KANBAN.ATTACHMENTS.EMPTY') }}
    </p>
    <input ref="fileInput" type="file" class="text-xs text-n-slate-11" @change="onPick" />
  </div>
</template>
