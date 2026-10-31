<script setup>
import { INBOX_COLOR_PALETTE } from 'dashboard/constants/customInboxColors';

const props = defineProps({
  modelValue: { type: String, default: null },
});
const emit = defineEmits(['update:modelValue']);

const palette = INBOX_COLOR_PALETTE;

const select = color => emit('update:modelValue', color);
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <button
      v-for="color in palette"
      :key="color"
      type="button"
      data-testid="color-swatch"
      class="size-6 rounded-full border border-n-weak transition-transform hover:scale-110"
      :class="modelValue === color ? 'ring-2 ring-offset-2 ring-n-slate-11' : ''"
      :style="{ backgroundColor: color }"
      :title="color"
      @click="select(color)"
    />
    <button
      type="button"
      data-testid="color-none"
      class="flex items-center gap-1 px-2 h-6 rounded-full border border-n-weak text-label-small text-n-slate-11"
      :class="modelValue === null ? 'ring-2 ring-offset-2 ring-n-slate-11' : ''"
      @click="select(null)"
    >
      {{ $t('INBOX_MGMT.CUSTOM_COLOR.NONE') }}
    </button>
  </div>
</template>
