<script setup>
import { ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { KANBAN_LABEL_PALETTE } from '../constants';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  labels: { type: Array, default: () => [] },
  modelValue: { type: Array, default: () => [] },
});
const emit = defineEmits(['update:modelValue']);

const store = useStore();
const { t } = useI18n();

// null = not editing; 'new' = creating; <id> = editing that label.
const editing = ref(null);
const draftName = ref('');
const draftColor = ref(KANBAN_LABEL_PALETTE[0]);

const toggle = id => {
  const next = props.modelValue.includes(id)
    ? props.modelValue.filter(x => x !== id)
    : [...props.modelValue, id];
  emit('update:modelValue', next);
};

const startCreate = () => {
  editing.value = 'new';
  draftName.value = '';
  draftColor.value = KANBAN_LABEL_PALETTE[0];
};

const startEdit = label => {
  editing.value = label.id;
  draftName.value = label.name;
  draftColor.value = label.color;
};

const cancel = () => {
  editing.value = null;
};

const save = async () => {
  const name = draftName.value.trim();
  if (!name) return;
  if (editing.value === 'new') {
    await store.dispatch('kanban/createLabel', {
      boardId: props.boardId,
      name,
      color: draftColor.value,
    });
  } else {
    await store.dispatch('kanban/updateLabel', {
      boardId: props.boardId,
      id: editing.value,
      name,
      color: draftColor.value,
    });
  }
  editing.value = null;
};

const remove = async label => {
  await store.dispatch('kanban/deleteLabel', {
    boardId: props.boardId,
    id: label.id,
  });
  emit(
    'update:modelValue',
    props.modelValue.filter(x => x !== label.id)
  );
};
</script>

<template>
  <div class="flex flex-col gap-2 w-60">
    <ul class="flex flex-col gap-1 overflow-y-auto max-h-56">
      <li
        v-for="label in labels"
        :key="label.id"
        class="flex items-center gap-1"
      >
        <button
          type="button"
          class="flex items-center flex-1 h-7 gap-2 px-2 text-xs font-medium text-white rounded"
          :style="{
            backgroundColor: label.color,
            opacity: modelValue.includes(label.id) ? 1 : 0.55,
          }"
          @click="toggle(label.id)"
        >
          <span class="flex-1 truncate text-start">{{ label.name }}</span>
          <Icon
            v-if="modelValue.includes(label.id)"
            icon="i-lucide-check"
            class="size-3.5"
          />
        </button>
        <button
          type="button"
          class="text-n-slate-10 hover:text-n-slate-12"
          :title="t('KANBAN.LABELS.EDIT')"
          @click="startEdit(label)"
        >
          <Icon icon="i-lucide-pencil" class="size-3.5" />
        </button>
      </li>
    </ul>

    <div
      v-if="editing !== null"
      class="flex flex-col gap-2 pt-2 border-t border-n-weak"
    >
      <input
        v-model="draftName"
        :placeholder="t('KANBAN.LABELS.NAME')"
        class="px-2 py-1.5 text-xs border rounded border-n-weak bg-n-alpha-black1 text-n-slate-12"
      />
      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="color in KANBAN_LABEL_PALETTE"
          :key="color"
          type="button"
          class="rounded-full size-5"
          :style="{ backgroundColor: color }"
          :class="
            draftColor === color ? 'ring-2 ring-offset-1 ring-n-slate-11' : ''
          "
          @click="draftColor = color"
        />
      </div>
      <div class="flex items-center justify-between">
        <button
          v-if="editing !== 'new'"
          type="button"
          class="text-xs text-n-ruby-11"
          @click="remove(labels.find(l => l.id === editing))"
        >
          {{ t('KANBAN.LABELS.DELETE') }}
        </button>
        <div class="flex gap-2 ms-auto">
          <button type="button" class="text-xs text-n-slate-10" @click="cancel">
            {{ t('KANBAN.COMMENTS.CANCEL') }}
          </button>
          <button
            type="button"
            class="px-2 py-1 text-xs text-white rounded bg-n-brand"
            @click="save"
          >
            {{ t('KANBAN.CARD.SAVE') }}
          </button>
        </div>
      </div>
    </div>
    <button
      v-else
      type="button"
      class="self-start text-xs text-n-brand"
      @click="startCreate"
    >
      {{ `+ ${t('KANBAN.LABELS.NEW')}` }}
    </button>
  </div>
</template>
