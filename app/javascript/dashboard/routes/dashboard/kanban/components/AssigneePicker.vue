<script setup>
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  members: { type: Array, default: () => [] },
  modelValue: { type: Array, default: () => [] },
});
const emit = defineEmits(['update:modelValue']);

const toggle = userId => {
  const next = props.modelValue.includes(userId)
    ? props.modelValue.filter(id => id !== userId)
    : [...props.modelValue, userId];
  emit('update:modelValue', next);
};
</script>

<template>
  <ul class="flex flex-col gap-1 overflow-y-auto max-h-48">
    <li v-for="member in members" :key="member.user_id">
      <button
        type="button"
        class="flex items-center w-full gap-2 px-2 py-1.5 text-sm rounded-lg text-n-slate-12 hover:bg-n-alpha-black2"
        @click="toggle(member.user_id)"
      >
        <Avatar
          :name="member.name"
          :src="member.thumbnail"
          :size="24"
          rounded-full
        />
        <span class="flex-1 truncate text-start">{{ member.name }}</span>
        <Icon
          v-if="modelValue.includes(member.user_id)"
          icon="i-lucide-check"
          class="size-4 text-n-brand"
        />
      </button>
    </li>
  </ul>
</template>
