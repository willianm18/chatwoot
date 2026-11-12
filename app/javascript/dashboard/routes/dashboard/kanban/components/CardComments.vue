<script setup>
import { ref, computed } from 'vue';
import { format, parseISO } from 'date-fns';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { ARTICLE_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  card: { type: Object, required: true },
  isOwner: { type: Boolean, default: false },
  // Only one rich editor may be mounted at a time in the dialog (the editor
  // component keeps its ProseMirror view in a module-level variable, so two
  // instances clobber each other). The parent gates this one via `active`.
  active: { type: Boolean, default: false },
});
const emit = defineEmits(['activate', 'deactivate']);

const store = useStore();
const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');
const { formatMessage } = useMessageFormatter();
const draft = ref('');
const editorKey = ref(0); // bump to reset the editor after sending

// Newest first.
const sortedComments = computed(() =>
  [...(props.card.comments ?? [])].reverse()
);

const formatStamp = iso =>
  iso ? format(parseISO(iso), 'd MMM yyyy, HH:mm') : '';

// Inline images render small; clicking one opens it full-size in a new tab.
const openImageInNewTab = event => {
  if (event.target.tagName === 'IMG') {
    window.open(event.target.src, '_blank', 'noopener');
  }
};

const canManage = comment =>
  comment.author_id === currentUser.value.id || props.isOwner;

const add = async () => {
  if (!draft.value.trim()) return;
  await store.dispatch('kanban/createComment', {
    boardId: props.boardId,
    cardId: props.card.id,
    content: draft.value.trim(),
  });
  draft.value = '';
  editorKey.value += 1;
  emit('deactivate');
};

const cancel = () => {
  draft.value = '';
  editorKey.value += 1;
  emit('deactivate');
};

const remove = comment =>
  store.dispatch('kanban/deleteComment', {
    boardId: props.boardId,
    cardId: props.card.id,
    id: comment.id,
  });
</script>

<template>
  <div class="flex flex-col h-full gap-2 min-h-0">
    <h4 class="text-sm font-medium shrink-0 text-n-slate-12">
      {{ t('KANBAN.COMMENTS.TITLE') }}
    </h4>

    <!-- Composer fixed at the top: a placeholder until clicked, then the editor -->
    <div class="shrink-0">
      <div v-if="active" class="flex flex-col gap-2">
        <FullEditor
          v-model="draft"
          :editor-id="`kanban-comment-${card.id}-${editorKey}`"
          :placeholder="t('KANBAN.COMMENTS.PLACEHOLDER')"
          :enabled-menu-options="ARTICLE_EDITOR_MENU_OPTIONS"
          autofocus
          class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12 [&_.ProseMirror-woot-style]:min-h-[8rem]"
        />
        <div class="flex items-center self-end gap-2">
          <button
            class="text-sm text-n-slate-10 hover:text-n-slate-12"
            @click="cancel"
          >
            {{ t('KANBAN.COMMENTS.CANCEL') }}
          </button>
          <button
            class="px-3 py-1.5 text-sm text-white rounded-lg bg-n-brand"
            @click="add"
          >
            {{ t('KANBAN.COMMENTS.SEND') }}
          </button>
        </div>
      </div>
      <button
        v-else
        type="button"
        class="flex items-center w-full gap-2 px-3 py-2.5 text-sm border rounded-lg text-start text-n-slate-11 bg-n-alpha-black2 border-n-strong hover:bg-n-alpha-black3 hover:text-n-slate-12"
        @click="emit('activate')"
      >
        <Icon
          icon="i-lucide-message-square-plus"
          class="size-4 text-n-slate-10"
        />
        {{ t('KANBAN.COMMENTS.PLACEHOLDER') }}
      </button>
    </div>

    <!-- Scrollable comment list -->
    <ul
      v-if="sortedComments.length"
      class="flex flex-col flex-1 gap-2 overflow-y-auto min-h-0"
    >
      <li
        v-for="comment in sortedComments"
        :key="comment.id"
        class="flex flex-col gap-0.5 p-2 rounded-lg bg-n-alpha-black1"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-xs font-medium text-n-slate-11">
            {{ comment.author_name }}
          </span>
          <div class="flex items-center gap-2 shrink-0">
            <span class="text-xs text-n-slate-10">
              {{ formatStamp(comment.created_at) }}
            </span>
            <button
              v-if="canManage(comment)"
              class="text-xs text-n-ruby-11"
              @click="remove(comment)"
            >
              {{ t('KANBAN.COMMENTS.DELETE') }}
            </button>
          </div>
        </div>
        <!-- eslint-disable-next-line vue/no-v-html -->
        <div
          class="text-sm prose-sm text-n-slate-12 max-w-none [&_img]:max-h-32 [&_img]:w-auto [&_img]:rounded [&_img]:cursor-zoom-in [&_img]:my-1"
          @click="openImageInNewTab"
          v-html="formatMessage(comment.content, false, false)"
        />
      </li>
    </ul>
    <p v-else class="text-xs shrink-0 text-n-slate-10">
      {{ t('KANBAN.COMMENTS.EMPTY') }}
    </p>
  </div>
</template>
