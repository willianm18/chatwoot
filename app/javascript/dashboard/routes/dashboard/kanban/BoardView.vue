<script setup>
import { onMounted, computed, ref } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import KanbanColumn from './components/KanbanColumn.vue';
import CardDialog from './components/CardDialog.vue';
import BoardMembersDialog from './components/BoardMembersDialog.vue';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
});

const store = useStore();
const { t } = useI18n();

const board = useMapGetter('kanban/getCurrentBoard');
const agents = useMapGetter('agents/getAgents');
const columns = computed(() => board.value?.columns ?? []);
const labels = computed(() => board.value?.labels ?? []);
const isOwner = computed(() => board.value?.owner);

const cardDialog = ref(null);
const membersDialog = ref(null);
const activeCard = ref(null);
const activeColumnId = ref(null);
const assigneeFilter = ref(null);
const labelFilter = ref(null);

onMounted(() => {
  store.dispatch('kanban/fetchBoard', props.boardId);
  store.dispatch('agents/get');
});

const visibleCards = column =>
  column.cards.filter(
    card =>
      (!assigneeFilter.value || card.assignee_id === assigneeFilter.value) &&
      (!labelFilter.value || card.label_ids?.includes(labelFilter.value))
  );

const onCardMoved = ({ cardId, toColumnId, position }) =>
  store.dispatch('kanban/moveCard', { cardId, toColumnId, position });

const openCard = card => {
  activeCard.value = card;
  activeColumnId.value = null;
  cardDialog.value.open();
};

const addCard = column => {
  activeCard.value = null;
  activeColumnId.value = column.id;
  cardDialog.value.open();
};

const addColumn = () =>
  store.dispatch('kanban/createColumn', {
    boardId: props.boardId,
    name: t('KANBAN.NEW_COLUMN'),
  });

const clearFilters = () => {
  assigneeFilter.value = null;
  labelFilter.value = null;
};
</script>

<template>
  <section v-if="board" class="flex flex-col w-full h-full bg-n-surface-1">
    <header
      class="flex flex-wrap items-center gap-3 px-4 py-3 border-b border-n-weak"
    >
      <h1 class="text-lg font-medium text-n-slate-12">{{ board.name }}</h1>
      <select
        v-model="assigneeFilter"
        class="px-2 py-1 text-xs border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
      >
        <option :value="null">{{ t('KANBAN.FILTERS.ASSIGNEE') }}</option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>
      <select
        v-model="labelFilter"
        class="px-2 py-1 text-xs border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
      >
        <option :value="null">{{ t('KANBAN.FILTERS.LABEL') }}</option>
        <option v-for="label in labels" :key="label.id" :value="label.id">
          {{ label.name }}
        </option>
      </select>
      <button
        v-if="assigneeFilter || labelFilter"
        class="text-xs text-n-slate-10 hover:text-n-slate-12"
        @click="clearFilters"
      >
        {{ t('KANBAN.FILTERS.CLEAR') }}
      </button>
      <Button
        v-if="isOwner"
        sm
        ghost
        slate
        :label="t('KANBAN.MEMBERS')"
        class="ms-auto"
        @click="membersDialog.open()"
      />
    </header>
    <div class="flex flex-1 gap-3 p-4 overflow-x-auto">
      <KanbanColumn
        v-for="column in columns"
        :key="column.id"
        :column="column"
        :cards="visibleCards(column)"
        :labels="labels"
        @card-moved="onCardMoved"
        @add-card="addCard"
        @open-card="openCard"
      />
      <button
        class="h-10 text-sm border border-dashed w-72 shrink-0 rounded-xl border-n-weak text-n-slate-10 hover:text-n-slate-12"
        @click="addColumn"
      >
        + {{ t('KANBAN.NEW_COLUMN') }}
      </button>
    </div>
    <CardDialog
      ref="cardDialog"
      :board-id="boardId"
      :card="activeCard"
      :column-id="activeColumnId"
      :labels="labels"
    />
    <BoardMembersDialog ref="membersDialog" :board-id="boardId" />
  </section>
</template>
