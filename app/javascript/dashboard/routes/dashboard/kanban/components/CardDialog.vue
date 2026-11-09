<script setup>
import { ref, watch, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import CardComments from './CardComments.vue';
import CardAttachments from './CardAttachments.vue';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  card: { type: Object, default: null },
  columnId: { type: [String, Number], default: null },
  labels: { type: Array, default: () => [] },
  isOwner: { type: Boolean, default: false },
});

const store = useStore();
const { t } = useI18n();
const dialogRef = ref(null);
const agents = useMapGetter('agents/getAgents');
const currentBoard = useMapGetter('kanban/getCurrentBoard');

// Live card: re-reads from the store after every refetch so new comments /
// attachments show without reopening the dialog. Falls back to the prop so
// the first render (before the board loads) works too.
const liveCard = computed(() => {
  if (!props.card) return null;
  const columns = currentBoard.value?.columns ?? [];
  return (
    columns.flatMap(c => c.cards).find(c => c.id === props.card.id) ??
    props.card
  );
});

const emptyForm = () => ({
  title: '',
  description: '',
  assignee_id: null,
  due_date: null,
  label_ids: [],
});
const form = ref(emptyForm());

watch(
  () => props.card,
  card => {
    form.value = card
      ? {
          title: card.title,
          description: card.description,
          assignee_id: card.assignee_id,
          due_date: card.due_date,
          label_ids: [...(card.label_ids || [])],
        }
      : emptyForm();
  },
  { immediate: true }
);

const open = () => dialogRef.value?.open();
defineExpose({ open });

const toggleLabel = id => {
  const index = form.value.label_ids.indexOf(id);
  if (index === -1) form.value.label_ids.push(id);
  else form.value.label_ids.splice(index, 1);
};

const save = async () => {
  if (!form.value.title.trim()) return;
  if (props.card) {
    await store.dispatch('kanban/updateCard', {
      boardId: props.boardId,
      id: props.card.id,
      ...form.value,
    });
  } else {
    await store.dispatch('kanban/createCard', {
      boardId: props.boardId,
      column_id: props.columnId,
      ...form.value,
    });
  }
  dialogRef.value?.close();
};

const remove = async () => {
  await store.dispatch('kanban/deleteCard', {
    boardId: props.boardId,
    id: props.card.id,
  });
  dialogRef.value?.close();
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('KANBAN.CARD.TITLE')"
    :show-confirm-button="false"
    :show-cancel-button="false"
  >
    <div class="flex flex-col gap-3">
      <input
        v-model="form.title"
        :placeholder="t('KANBAN.CARD.TITLE')"
        class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
      />
      <textarea
        v-model="form.description"
        :placeholder="t('KANBAN.CARD.DESCRIPTION')"
        rows="3"
        class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
      />
      <select
        v-model="form.assignee_id"
        class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
      >
        <option :value="null">{{ t('KANBAN.CARD.ASSIGNEE') }}</option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>
      <input
        v-model="form.due_date"
        type="date"
        class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
      />
      <div v-if="labels.length" class="flex flex-wrap gap-2">
        <button
          v-for="label in labels"
          :key="label.id"
          type="button"
          class="h-6 px-2 text-xs text-white rounded-full"
          :style="{
            backgroundColor: label.color,
            opacity: form.label_ids.includes(label.id) ? 1 : 0.4,
          }"
          @click="toggleLabel(label.id)"
        >
          {{ label.name }}
        </button>
      </div>
      <div class="flex items-center justify-between">
        <button v-if="card" class="text-sm text-n-ruby-11" @click="remove">
          {{ t('KANBAN.CARD.DELETE') }}
        </button>
        <button
          class="px-3 py-1.5 ms-auto text-sm text-white rounded-lg bg-n-brand"
          @click="save"
        >
          {{ t('KANBAN.CARD.SAVE') }}
        </button>
      </div>
      <template v-if="liveCard">
        <hr class="border-n-weak" />
        <CardComments
          :board-id="boardId"
          :card="liveCard"
          :is-owner="isOwner"
        />
        <hr class="border-n-weak" />
        <CardAttachments :board-id="boardId" :card="liveCard" />
      </template>
    </div>
  </Dialog>
</template>
