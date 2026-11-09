<script setup>
import { ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import KanbanAPI from 'dashboard/api/custom/kanban';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
});

const { t } = useI18n();
const dialogRef = ref(null);
const members = ref([]);
const agents = useMapGetter('agents/getAgents');

const load = async () => {
  const { data } = await KanbanAPI.getMembers(props.boardId);
  members.value = data.payload;
};

const open = async () => {
  await load();
  dialogRef.value?.open();
};
defineExpose({ open });

const add = async event => {
  const userId = event.target.value;
  if (!userId) return;
  await KanbanAPI.addMember(props.boardId, userId);
  await load();
};

const remove = async memberId => {
  await KanbanAPI.removeMember(props.boardId, memberId);
  await load();
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('KANBAN.MEMBERS')"
    :show-confirm-button="false"
    :show-cancel-button="false"
  >
    <ul class="flex flex-col gap-2">
      <li
        v-for="member in members"
        :key="member.id"
        class="flex items-center justify-between text-sm text-n-slate-12"
      >
        <span>
          {{ member.name }}
          <span v-if="member.owner" class="text-xs ms-2 text-n-slate-10">
            {{ `(${t('KANBAN.OWNER')})` }}
          </span>
        </span>
        <button
          v-if="!member.owner"
          class="text-n-ruby-11"
          @click="remove(member.id)"
        >
          <Icon icon="i-lucide-x" class="size-3.5" />
        </button>
      </li>
    </ul>
    <select
      class="w-full px-3 py-2 mt-3 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
      @change="add"
    >
      <option value="">{{ t('KANBAN.ADD_MEMBER') }}</option>
      <option v-for="agent in agents" :key="agent.id" :value="agent.id">
        {{ agent.name }}
      </option>
    </select>
  </Dialog>
</template>
