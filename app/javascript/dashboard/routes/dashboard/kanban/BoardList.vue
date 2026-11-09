<script setup>
import { onMounted, computed, ref } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const router = useRouter();
const { t } = useI18n();

const boards = useMapGetter('kanban/getBoards');
const newName = ref('');

onMounted(() => store.dispatch('kanban/fetchBoards'));

const openBoard = id =>
  router.push({ name: 'kanban_board', params: { boardId: id } });

const createBoard = async () => {
  if (!newName.value.trim()) return;
  const board = await store.dispatch('kanban/createBoard', {
    name: newName.value.trim(),
  });
  newName.value = '';
  openBoard(board.id);
};

const hasBoards = computed(() => boards.value.length > 0);
</script>

<template>
  <section
    class="flex flex-col w-full h-full gap-4 p-6 overflow-y-auto bg-n-surface-1"
  >
    <header class="flex items-center justify-between">
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('KANBAN.HEADER') }}
      </h1>
      <div class="flex gap-2">
        <input
          v-model="newName"
          :placeholder="t('KANBAN.BOARD_NAME')"
          class="px-3 py-1.5 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
          @keyup.enter="createBoard"
        />
        <Button
          sm
          solid
          blue
          :label="t('KANBAN.NEW_BOARD')"
          @click="createBoard"
        />
      </div>
    </header>
    <p v-if="!hasBoards" class="text-sm text-n-slate-11">
      {{ t('KANBAN.EMPTY_BOARDS') }}
    </p>
    <div v-else class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <button
        v-for="board in boards"
        :key="board.id"
        class="flex flex-col items-start gap-1 p-4 border text-start rounded-xl border-n-weak bg-n-solid-1 hover:border-n-brand"
        @click="openBoard(board.id)"
      >
        <span class="text-base font-medium text-n-slate-12">{{
          board.name
        }}</span>
        <span v-if="board.owner" class="text-xs text-n-slate-10">
          {{ t('KANBAN.OWNER') }}
        </span>
      </button>
    </div>
  </section>
</template>
