<script setup>
import { ref, watch, computed } from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import draggable from 'vuedraggable';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import InboxColorPicker from 'dashboard/components/custom/InboxColorPicker.vue';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  column: { type: Object, required: true },
  // Ids of the cards that pass the active filters; others are hidden with v-show
  // so the draggable list stays the full, stable column.cards array.
  visibleCardIds: { type: Array, required: true },
  labels: { type: Array, default: () => [] },
  members: { type: Array, default: () => [] },
});
const emit = defineEmits(['cardMoved', 'addCard', 'openCard']);
const store = useStore();
const { t } = useI18n();

const name = ref(props.column.name);
watch(
  () => props.column.name,
  value => {
    name.value = value;
  }
);

const renameColumn = () => {
  const trimmed = name.value.trim();
  if (!trimmed || trimmed === props.column.name) {
    name.value = props.column.name;
    return;
  }
  store.dispatch('kanban/updateColumn', {
    boardId: props.boardId,
    id: props.column.id,
    name: trimmed,
  });
};

const deleteColumn = () => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('KANBAN.COLUMN.DELETE_CONFIRM'))) return;
  store.dispatch('kanban/deleteColumn', {
    boardId: props.boardId,
    id: props.column.id,
  });
};

const onChange = event => {
  const change = event.added || event.moved;
  if (!change) return;
  emit('cardMoved', {
    cardId: change.element.id,
    toColumnId: props.column.id,
    position: change.newIndex,
  });
};

const showColorPicker = ref(false);

// Tinted header band when a color is set (dynamic data color → inline style,
// the accepted exception used by label pills and the per-inbox color).
const headerStyle = computed(() =>
  props.column.custom_color
    ? {
        backgroundColor: `${props.column.custom_color}26`,
        borderBottom: `1px solid ${props.column.custom_color}`,
      }
    : {}
);

const setColor = color => {
  showColorPicker.value = false;
  store.dispatch('kanban/updateColumn', {
    boardId: props.boardId,
    id: props.column.id,
    custom_color: color,
  });
};
</script>

<template>
  <div
    class="flex flex-col gap-2 p-2 w-72 shrink-0 rounded-xl bg-n-alpha-black1"
  >
    <div
      class="flex items-center gap-1 px-1 py-0.5 -mx-1 -mt-1 rounded-t-xl"
      :style="headerStyle"
    >
      <input
        v-model="name"
        class="flex-1 min-w-0 px-1 text-sm font-medium bg-transparent rounded text-n-slate-12 hover:bg-n-alpha-black2 focus:bg-n-alpha-black2"
        @keyup.enter="renameColumn"
        @blur="renameColumn"
      />
      <span
        class="px-1.5 text-xs rounded-full text-n-slate-10 bg-n-alpha-black2"
      >
        {{ column.cards.length }}
      </span>
      <div class="relative shrink-0">
        <button
          class="text-n-slate-10 hover:text-n-slate-12"
          :title="t('KANBAN.COLUMN.COLOR')"
          @click="showColorPicker = !showColorPicker"
        >
          <Icon icon="i-lucide-palette" class="size-3.5" />
        </button>
        <div
          v-if="showColorPicker"
          v-on-click-outside="() => (showColorPicker = false)"
          class="absolute z-10 p-2 mt-1 border rounded-lg shadow-lg ltr:right-0 rtl:left-0 bg-n-solid-1 border-n-weak"
        >
          <InboxColorPicker
            :model-value="column.custom_color ?? null"
            @update:model-value="setColor"
          />
        </div>
      </div>
      <button
        class="shrink-0 text-n-slate-10 hover:text-n-slate-12"
        :title="t('KANBAN.NEW_CARD')"
        @click="$emit('addCard', column)"
      >
        <Icon icon="i-lucide-plus" class="size-3.5" />
      </button>
      <button
        class="shrink-0 text-n-slate-10 hover:text-n-ruby-11"
        :title="t('KANBAN.COLUMN.DELETE')"
        @click="deleteColumn"
      >
        <Icon icon="i-lucide-trash-2" class="size-3.5" />
      </button>
    </div>
    <draggable
      :list="column.cards"
      group="kanban-cards"
      item-key="id"
      class="flex flex-col flex-1 gap-2 min-h-[80px]"
      @change="onChange"
    >
      <template #item="{ element }">
        <KanbanCard
          v-show="visibleCardIds.includes(element.id)"
          :card="element"
          :labels="labels"
          :members="members"
          @open="$emit('openCard', element)"
        />
      </template>
    </draggable>
    <button
      class="px-1 py-1 text-xs text-start text-n-slate-10 hover:text-n-slate-12"
      @click="$emit('addCard', column)"
    >
      {{ `+ ${t('KANBAN.NEW_CARD')}` }}
    </button>
  </div>
</template>
