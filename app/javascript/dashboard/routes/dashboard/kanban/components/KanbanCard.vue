<script setup>
import { computed } from 'vue';

const props = defineProps({
  card: { type: Object, required: true },
  labels: { type: Array, default: () => [] },
});
defineEmits(['open']);

const cardLabels = computed(() =>
  props.labels.filter(label => props.card.label_ids?.includes(label.id))
);
</script>

<template>
  <div
    class="flex flex-col gap-1.5 p-2.5 border rounded-lg cursor-pointer bg-n-solid-1 border-n-weak hover:border-n-brand"
    @click="$emit('open', card)"
  >
    <div v-if="cardLabels.length" class="flex flex-wrap gap-1">
      <span
        v-for="label in cardLabels"
        :key="label.id"
        class="h-1.5 w-8 rounded-full"
        :style="{ backgroundColor: label.color }"
      />
    </div>
    <span class="text-sm text-n-slate-12">{{ card.title }}</span>
    <span v-if="card.due_date" class="text-xs text-n-slate-10">
      {{ card.due_date }}
    </span>
  </div>
</template>
