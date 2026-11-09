<script setup>
import draggable from 'vuedraggable';
import { useI18n } from 'vue-i18n';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  column: { type: Object, required: true },
  cards: { type: Array, required: true },
  labels: { type: Array, default: () => [] },
});
const emit = defineEmits(['cardMoved', 'addCard', 'openCard']);
const { t } = useI18n();

const onChange = event => {
  const change = event.added || event.moved;
  if (!change) return;
  emit('cardMoved', {
    cardId: change.element.id,
    toColumnId: props.column.id,
    position: change.newIndex,
  });
};
</script>

<template>
  <div class="flex flex-col gap-2 p-2 w-72 shrink-0 rounded-xl bg-n-alpha-black1">
    <h3 class="px-1 text-sm font-medium text-n-slate-12">{{ column.name }}</h3>
    <draggable
      :list="cards"
      group="kanban-cards"
      item-key="id"
      class="flex flex-col gap-2 min-h-[8px]"
      @change="onChange"
    >
      <template #item="{ element }">
        <KanbanCard
          :card="element"
          :labels="labels"
          @open="$emit('openCard', element)"
        />
      </template>
    </draggable>
    <button
      class="px-1 py-1 text-xs text-start text-n-slate-10 hover:text-n-slate-12"
      @click="$emit('addCard', column)"
    >
      + {{ t('KANBAN.NEW_CARD') }}
    </button>
  </div>
</template>
