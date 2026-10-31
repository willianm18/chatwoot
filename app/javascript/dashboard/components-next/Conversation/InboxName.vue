<script setup>
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';

defineProps({
  inbox: {
    type: Object,
    default: () => {},
  },
});
</script>

<template>
  <div :title="inbox.name" class="flex items-center gap-0.5 min-w-0">
    <ChannelIcon :inbox="inbox" class="size-4 flex-shrink-0 text-n-slate-11" />
    <span
      class="truncate text-body-main"
      :class="
        inbox.custom_color ? 'px-1.5 py-0.5 rounded-full' : 'text-n-slate-11'
      "
      :style="
        inbox.custom_color
          ? {
              color: inbox.custom_color,
              backgroundColor: `${inbox.custom_color}1F`,
            }
          : {}
      "
    >
      {{ inbox.name }}
    </span>
  </div>
</template>
