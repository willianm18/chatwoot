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

const formatSize = bytes => {
  if (!bytes && bytes !== 0) return '';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

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

const openFilePicker = () => fileInput.value?.click();
defineExpose({ openFilePicker });
</script>

<template>
  <div class="flex flex-col gap-2">
    <h4 class="text-xs font-medium uppercase text-n-slate-10">
      {{ t('KANBAN.ATTACHMENTS.TITLE') }}
    </h4>
    <ul v-if="card.attachments?.length" class="flex flex-col gap-2">
      <li
        v-for="attachment in card.attachments"
        :key="attachment.id"
        class="flex items-center gap-3 p-2 border rounded-lg border-n-weak bg-n-alpha-black1"
      >
        <a
          :href="attachment.file_url"
          target="_blank"
          rel="noopener noreferrer"
          class="shrink-0"
        >
          <img
            v-if="attachment.is_image"
            :src="attachment.file_url"
            :alt="attachment.filename"
            class="object-cover rounded size-9"
          />
          <span
            v-else
            class="flex items-center justify-center rounded size-9 bg-n-alpha-black2"
          >
            <Icon icon="i-lucide-file" class="size-4 text-n-slate-11" />
          </span>
        </a>
        <div class="flex-1 min-w-0">
          <a
            :href="attachment.file_url"
            target="_blank"
            rel="noopener noreferrer"
            class="block text-sm truncate text-n-slate-12 hover:underline"
          >
            {{ attachment.filename }}
          </a>
          <span class="text-xs text-n-slate-10">
            {{ formatSize(attachment.byte_size) }}
          </span>
        </div>
        <button
          class="text-xs shrink-0 text-n-slate-10 hover:text-n-ruby-11"
          @click="remove(attachment)"
        >
          {{ t('KANBAN.ATTACHMENTS.REMOVE') }}
        </button>
      </li>
    </ul>
    <button
      type="button"
      class="self-start inline-flex items-center gap-1.5 px-3 py-2 text-sm rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
      @click="openFilePicker"
    >
      <Icon icon="i-lucide-paperclip" class="size-4" />
      {{ t('KANBAN.ATTACHMENTS.ADD') }}
    </button>
    <input ref="fileInput" type="file" class="hidden" @change="onPick" />
  </div>
</template>
