<script setup>
import { ref, watch, computed } from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import { useResizeObserver } from '@vueuse/core';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import { ARTICLE_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
import AssigneePicker from './AssigneePicker.vue';
import LabelPicker from './LabelPicker.vue';
import CardComments from './CardComments.vue';
import CardAttachments from './CardAttachments.vue';
import { formatDueDate, isOverdue } from '../cardDateFormat';

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

// Due date reveals its picker on demand (a button until then, like Trello).
const showDueDate = ref(false);

// Collapsed description preview with a "show more" toggle. Height-based (not
// character-based) so it also works when the description contains images; the
// resize observer re-measures when images finish loading.
const descriptionRef = ref(null);
const descriptionExpanded = ref(false);
const isDescriptionOverflowing = ref(false);
useResizeObserver(descriptionRef, () => {
  const el = descriptionRef.value;
  if (!el) return;
  isDescriptionOverflowing.value = el.scrollHeight > el.clientHeight + 4;
});

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
    descriptionExpanded.value = false;
    showDueDate.value = false;
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
const selectedLabels = computed(() =>
  props.labels.filter(l => form.value.label_ids.includes(l.id))
);
const showAssigneePicker = ref(false);
const showLabelPicker = ref(false);
const attachmentsRef = ref(null);

const clearDueDate = () => {
  form.value.due_date = null;
  showDueDate.value = false;
};

// Clicking an image in the description opens it full-size; clicking text edits.
const onDescriptionClick = event => {
  if (event.target.tagName === 'IMG') {
    event.stopPropagation();
    window.open(event.target.src, '_blank', 'noopener');
    return;
  }
  activeEditor.value = 'description';
};

const open = () => dialogRef.value?.open();
defineExpose({ open });

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
    <div class="flex flex-col">
      <div class="flex flex-col gap-2 mb-3 shrink-0">
        <span
          v-if="columnName"
          class="self-start px-2 py-0.5 text-xs font-medium rounded-full text-n-slate-11 bg-n-alpha-black2"
        >
          {{ columnName }}
        </span>
        <input
          v-model="form.title"
          :placeholder="t('KANBAN.CARD.TITLE')"
          class="px-1 py-0.5 text-lg font-semibold bg-transparent rounded text-n-slate-12 hover:bg-n-alpha-black2 focus:bg-n-alpha-black2"
        />
      </div>

      <!-- Trello-style quick-add action bar -->
      <div class="flex flex-wrap gap-2 mb-4 shrink-0">
        <button
          type="button"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
          @click="showLabelPicker = !showLabelPicker"
        >
          <Icon icon="i-lucide-tag" class="size-3.5" />
          {{ t('KANBAN.ACTIONS.LABEL') }}
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
          @click="showDueDate = true"
        >
          <Icon icon="i-lucide-calendar" class="size-3.5" />
          {{ t('KANBAN.ACTIONS.DATE') }}
        </button>
        <button
          v-if="liveCard"
          type="button"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
          @click="attachmentsRef?.openFilePicker()"
        >
          <Icon icon="i-lucide-paperclip" class="size-3.5" />
          {{ t('KANBAN.ACTIONS.ATTACHMENT') }}
        </button>
      </div>

      <div class="flex flex-col gap-6 md:h-[70vh] md:flex-row">
        <!-- Left column: card (scrolls on its own) -->
        <div
          class="flex flex-col flex-1 min-w-0 gap-4 md:overflow-y-auto md:min-h-0 md:pe-6 md:border-e md:border-n-weak"
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
                  class="flex items-center justify-center rounded-full size-7 bg-n-alpha-black2 text-n-slate-11 hover:bg-n-alpha-black3 hover:text-n-slate-12"
                  :title="t('KANBAN.CARD.ASSIGNEES')"
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
            <div class="flex flex-wrap items-center gap-2">
              <span
                v-for="label in selectedLabels"
                :key="label.id"
                class="h-6 px-2 text-xs leading-6 text-white rounded-full"
                :style="{ backgroundColor: label.color }"
              >
                {{ label.name }}
              </span>
              <div class="relative">
                <button
                  type="button"
                  class="flex items-center justify-center rounded-full size-6 bg-n-alpha-black2 text-n-slate-11 hover:bg-n-alpha-black3"
                  @click="showLabelPicker = !showLabelPicker"
                >
                  <Icon icon="i-lucide-plus" class="size-3.5" />
                </button>
                <div
                  v-if="showLabelPicker"
                  v-on-click-outside="() => (showLabelPicker = false)"
                  class="absolute z-10 p-2 mt-1 border rounded-lg shadow-lg bg-n-solid-1 border-n-weak"
                >
                  <LabelPicker
                    v-model="form.label_ids"
                    :board-id="boardId"
                    :labels="labels"
                  />
                </div>
              </div>
            </div>
          </section>

          <section class="flex flex-col gap-2">
            <h4 class="text-xs font-medium uppercase text-n-slate-10">
              {{ t('KANBAN.CARD.DUE_DATE') }}
            </h4>
            <input
              v-if="showDueDate && !form.due_date"
              v-model="form.due_date"
              type="date"
              class="self-start w-auto px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black1 text-n-slate-12"
            />
            <span
              v-else-if="form.due_date"
              class="inline-flex items-center self-start gap-2 px-3 py-1.5 text-sm font-medium rounded-full"
              :class="
                isOverdue(form.due_date)
                  ? 'bg-n-ruby-3 text-n-ruby-11'
                  : 'bg-n-alpha-black2 text-n-slate-11'
              "
            >
              <Icon icon="i-lucide-calendar" class="size-3.5" />
              {{ formatDueDate(form.due_date) }}
              <button
                type="button"
                class="opacity-70 hover:opacity-100"
                :title="t('KANBAN.CARD.CLEAR_DUE_DATE')"
                @click="clearDueDate"
              >
                <Icon icon="i-lucide-x" class="size-3.5" />
              </button>
            </span>
            <button
              v-else
              type="button"
              class="self-start inline-flex items-center gap-1.5 px-3 py-2 text-sm rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
              @click="showDueDate = true"
            >
              <Icon icon="i-lucide-calendar" class="size-4" />
              {{ t('KANBAN.CARD.SET_DUE_DATE') }}
            </button>
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
              class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12 [&_.ProseMirror-woot-style]:min-h-[14rem]"
            />
            <div v-else-if="form.description" class="flex flex-col gap-1">
              <!-- eslint-disable-next-line vue/no-v-html -->
              <div
                ref="descriptionRef"
                class="px-3 py-2 text-xs prose-sm leading-relaxed rounded-lg cursor-text text-n-slate-12 max-w-none bg-n-alpha-black1 hover:bg-n-alpha-black2 [&_img]:max-h-32 [&_img]:w-auto [&_img]:rounded [&_img]:cursor-zoom-in [&_img]:my-1"
                :class="descriptionExpanded ? '' : 'max-h-40 overflow-hidden'"
                @click="onDescriptionClick"
                v-html="formatMessage(form.description, false, false)"
              />
              <button
                v-if="isDescriptionOverflowing || descriptionExpanded"
                type="button"
                class="self-start text-xs text-n-brand"
                @click.stop="descriptionExpanded = !descriptionExpanded"
              >
                {{
                  descriptionExpanded
                    ? t('COMPONENTS.SHOW_MORE_BLOCK.SHOW_LESS')
                    : t('COMPONENTS.SHOW_MORE_BLOCK.SHOW_MORE')
                }}
              </button>
            </div>
            <button
              v-else
              type="button"
              class="px-3 py-2 text-sm rounded-lg text-start text-n-slate-10 bg-n-alpha-black1 hover:bg-n-alpha-black2"
              @click="activeEditor = 'description'"
            >
              {{ t('KANBAN.CARD.ADD_DESCRIPTION') }}
            </button>
          </section>

          <CardAttachments
            v-if="liveCard"
            ref="attachmentsRef"
            :board-id="boardId"
            :card="liveCard"
          />

          <div
            class="flex items-center justify-between pt-3 mt-2 border-t shrink-0 border-n-weak"
          >
            <button
              v-if="card"
              type="button"
              class="inline-flex items-center gap-1.5 text-sm text-n-ruby-11 hover:text-n-ruby-10"
              @click="remove"
            >
              <Icon icon="i-lucide-trash-2" class="size-4" />
              {{ t('KANBAN.CARD.DELETE') }}
            </button>
            <button
              type="button"
              class="px-4 py-2 text-sm font-medium text-white rounded-lg ms-auto bg-n-brand hover:opacity-90"
              @click="save"
            >
              {{ t('KANBAN.CARD.SAVE') }}
            </button>
          </div>
        </div>

        <!-- Right column: comments (scrolls on its own) -->
        <div
          v-if="liveCard"
          class="flex flex-col min-w-0 shrink-0 md:w-96 md:min-h-0"
        >
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
    </div>
  </Dialog>
</template>
