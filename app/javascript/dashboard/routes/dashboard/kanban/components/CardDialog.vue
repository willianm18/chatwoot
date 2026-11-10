<script setup>
import { ref, watch, computed } from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import { ARTICLE_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
import AssigneePicker from './AssigneePicker.vue';
import CardComments from './CardComments.vue';
import CardAttachments from './CardAttachments.vue';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  card: { type: Object, default: null },
  columnId: { type: [String, Number], default: null },
  labels: { type: Array, default: () => [] },
  members: { type: Array, default: () => [] },
  isOwner: { type: Boolean, default: false },
});

const store = useStore();
const { t } = useI18n();
const { formatMessage } = useMessageFormatter();
const dialogRef = ref(null);
const currentBoard = useMapGetter('kanban/getCurrentBoard');

// Guarantees at most one rich editor is mounted at a time (description or the
// comment composer). The editor keeps its ProseMirror view in a module-level
// variable, so two simultaneous instances would write to the same view.
const activeEditor = ref(null);

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

const columnName = computed(() => {
  const columns = currentBoard.value?.columns ?? [];
  const columnId = props.card
    ? columns.find(c => c.cards.some(card => card.id === props.card.id))?.id
    : props.columnId;
  return columns.find(c => c.id === columnId)?.name ?? '';
});

const emptyForm = () => ({
  title: '',
  description: '',
  assignee_ids: [],
  due_date: null,
  label_ids: [],
});
const form = ref(emptyForm());

watch(
  () => props.card,
  card => {
    activeEditor.value = null;
    form.value = card
      ? {
          title: card.title,
          description: card.description,
          assignee_ids: [...(card.assignee_ids || [])],
          due_date: card.due_date,
          label_ids: [...(card.label_ids || [])],
        }
      : emptyForm();
  },
  { immediate: true }
);

const selectedAssignees = computed(() =>
  props.members.filter(m => form.value.assignee_ids.includes(m.user_id))
);
const showAssigneePicker = ref(false);

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
    width="5xl"
    :show-confirm-button="false"
    :show-cancel-button="false"
  >
    <div class="flex flex-col gap-1 mb-4">
      <input
        v-model="form.title"
        :placeholder="t('KANBAN.CARD.TITLE')"
        class="px-1 py-0.5 text-base font-medium bg-transparent rounded text-n-slate-12 hover:bg-n-alpha-black2 focus:bg-n-alpha-black2"
      />
      <span v-if="columnName" class="px-1 text-xs text-n-slate-10">
        {{ t('KANBAN.CARD.IN_COLUMN', { column: columnName }) }}
      </span>
    </div>

    <div class="flex flex-col gap-6 md:flex-row">
      <!-- Left column: card -->
      <div
        class="flex flex-col flex-1 min-w-0 gap-4 md:border-e md:border-n-weak md:pe-6"
      >
        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.ASSIGNEES') }}
          </h4>
          <div class="flex flex-wrap items-center gap-2">
            <span
              v-for="assignee in selectedAssignees"
              :key="assignee.user_id"
              class="flex items-center gap-1.5 py-0.5 rounded-full ps-1 pe-2 bg-n-alpha-black2"
            >
              <Avatar
                :name="assignee.name"
                :src="assignee.thumbnail"
                :size="20"
                rounded-full
              />
              <span class="text-xs text-n-slate-12">{{ assignee.name }}</span>
            </span>
            <div class="relative">
              <button
                type="button"
                class="flex items-center justify-center border border-dashed rounded-full size-7 border-n-weak text-n-slate-10 hover:text-n-slate-12"
                @click="showAssigneePicker = !showAssigneePicker"
              >
                <Icon icon="i-lucide-plus" class="size-4" />
              </button>
              <div
                v-if="showAssigneePicker"
                v-on-click-outside="() => (showAssigneePicker = false)"
                class="absolute z-10 p-2 mt-1 border rounded-lg shadow-lg bg-n-solid-1 border-n-weak w-56"
              >
                <AssigneePicker
                  v-model="form.assignee_ids"
                  :members="members"
                />
              </div>
            </div>
          </div>
        </section>

        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.LABELS') }}
          </h4>
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
        </section>

        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.DUE_DATE') }}
          </h4>
          <input
            v-model="form.due_date"
            type="date"
            class="self-start px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
          />
        </section>

        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.DESCRIPTION') }}
          </h4>
          <FullEditor
            v-if="activeEditor === 'description'"
            v-model="form.description"
            :editor-id="`kanban-desc-${card?.id ?? 'new'}`"
            :placeholder="t('KANBAN.CARD.DESCRIPTION')"
            :enabled-menu-options="ARTICLE_EDITOR_MENU_OPTIONS"
            autofocus
            class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
          />
          <!-- eslint-disable-next-line vue/no-v-html -->
          <div
            v-else-if="form.description"
            class="px-3 py-2 text-sm prose-sm rounded-lg cursor-text text-n-slate-12 max-w-none bg-n-alpha-black1 hover:bg-n-alpha-black2"
            @click="activeEditor = 'description'"
            v-html="formatMessage(form.description, false, false)"
          />
          <button
            v-else
            type="button"
            class="px-3 py-2 text-sm rounded-lg text-start text-n-slate-10 bg-n-alpha-black1 hover:bg-n-alpha-black2"
            @click="activeEditor = 'description'"
          >
            {{ t('KANBAN.CARD.ADD_DESCRIPTION') }}
          </button>
        </section>

        <CardAttachments v-if="liveCard" :board-id="boardId" :card="liveCard" />

        <div class="flex items-center justify-between mt-2">
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
      </div>

      <!-- Right column: comments -->
      <div v-if="liveCard" class="flex flex-col min-w-0 shrink-0 md:w-72">
        <CardComments
          :board-id="boardId"
          :card="liveCard"
          :is-owner="isOwner"
          :active="activeEditor === 'comment'"
          @activate="activeEditor = 'comment'"
          @deactivate="activeEditor = null"
        />
      </div>
    </div>
  </Dialog>
</template>
