<script setup>
import { computed } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { formatDueDate, isOverdue } from '../cardDateFormat';

const props = defineProps({
  card: { type: Object, required: true },
  labels: { type: Array, default: () => [] },
  members: { type: Array, default: () => [] },
});
defineEmits(['open']);

const cardLabels = computed(() =>
  props.labels.filter(label => props.card.label_ids?.includes(label.id))
);

const cardAssignees = computed(() =>
  props.members.filter(member =>
    props.card.assignee_ids?.includes(member.user_id)
  )
);

const dueLabel = computed(() => formatDueDate(props.card.due_date));
const dueOverdue = computed(() => isOverdue(props.card.due_date));
const commentCount = computed(() => props.card.comments?.length ?? 0);
const attachmentCount = computed(() => props.card.attachments?.length ?? 0);
const hasDescription = computed(() => Boolean(props.card.description?.trim()));
const hasFooter = computed(
  () =>
    dueLabel.value ||
    hasDescription.value ||
    commentCount.value ||
    attachmentCount.value ||
    cardAssignees.value.length
);
</script>

<template>
  <div
    class="flex flex-col gap-2 p-2.5 border rounded-lg cursor-pointer bg-n-solid-1 border-n-weak hover:border-n-brand"
    @click="$emit('open', card)"
  >
    <div v-if="cardLabels.length" class="flex flex-wrap gap-1">
      <span
        v-for="label in cardLabels"
        :key="label.id"
        class="px-2 py-0.5 text-xs font-medium text-white rounded-full"
        :style="{ backgroundColor: label.color }"
      >
        {{ label.name }}
      </span>
    </div>

    <span class="text-sm text-n-slate-12">{{ card.title }}</span>

    <div v-if="hasFooter" class="flex items-center justify-between gap-2">
      <div class="flex items-center gap-2 text-n-slate-10">
        <span
          v-if="dueLabel"
          class="inline-flex items-center gap-1 px-1.5 py-0.5 text-xs font-medium rounded-md"
          :class="
            dueOverdue
              ? 'bg-n-ruby-3 text-n-ruby-11'
              : 'bg-n-alpha-black2 text-n-slate-11'
          "
        >
          <Icon icon="i-lucide-calendar" class="size-3" />
          {{ dueLabel }}
        </span>
        <Icon
          v-if="hasDescription"
          icon="i-lucide-align-left"
          class="size-3.5"
        />
        <span
          v-if="commentCount"
          class="inline-flex items-center gap-0.5 text-xs"
        >
          <Icon icon="i-lucide-message-square" class="size-3.5" />
          {{ commentCount }}
        </span>
        <span
          v-if="attachmentCount"
          class="inline-flex items-center gap-0.5 text-xs"
        >
          <Icon icon="i-lucide-paperclip" class="size-3.5" />
          {{ attachmentCount }}
        </span>
      </div>
      <div
        v-if="cardAssignees.length"
        class="flex ltr:-space-x-2 rtl:space-x-reverse"
      >
        <Avatar
          v-for="assignee in cardAssignees"
          :key="assignee.user_id"
          :name="assignee.name"
          :src="assignee.thumbnail"
          :size="22"
          rounded-full
          class="rounded-full ring-2 ring-n-solid-1"
        />
      </div>
    </div>
  </div>
</template>
