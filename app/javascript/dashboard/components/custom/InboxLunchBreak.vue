<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import parse from 'date-fns/parse';
import getHours from 'date-fns/getHours';
import getMinutes from 'date-fns/getMinutes';
import differenceInMinutes from 'date-fns/differenceInMinutes';
import {
  generateTimeSlots,
  getTime,
} from 'dashboard/routes/dashboard/settings/inbox/helpers/businessHour';
import NextSelect from 'dashboard/components-next/select/Select.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update:modelValue', 'update:valid']);

const { t } = useI18n();

// Default window when the break is first enabled: 12:00 – 13:00.
const DEFAULTS = {
  start_hour: 12,
  start_minutes: 0,
  end_hour: 13,
  end_minutes: 0,
};

const timeSlots = generateTimeSlots(30);
const groupByPeriod = slots =>
  ['AM', 'PM']
    .map(period => ({
      label: period,
      options: slots
        .filter(s => s.endsWith(period))
        .map(s => ({ value: s, label: s })),
    }))
    .filter(group => group.options.length);

const timeSlotGroups = computed(() => groupByPeriod(timeSlots));

const current = () => ({ ...DEFAULTS, ...props.modelValue });

const update = patch => emit('update:modelValue', { ...current(), ...patch });

const isEnabled = computed({
  get: () => Boolean(props.modelValue.enabled),
  set: value => update({ enabled: value }),
});

const startTime = computed({
  get: () => getTime(current().start_hour, current().start_minutes),
  set: value => {
    const date = parse(value, 'hh:mm a', new Date());
    update({ start_hour: getHours(date), start_minutes: getMinutes(date) });
  },
});

const endTime = computed({
  get: () => getTime(current().end_hour, current().end_minutes),
  set: value => {
    const date = parse(value, 'hh:mm a', new Date());
    update({ end_hour: getHours(date), end_minutes: getMinutes(date) });
  },
});

const hasError = computed(() => {
  if (!isEnabled.value) return false;
  const start = parse(startTime.value, 'hh:mm a', new Date());
  const end = parse(endTime.value, 'hh:mm a', new Date());
  return differenceInMinutes(end, start) <= 0;
});

watch(hasError, value => emit('update:valid', !value), { immediate: true });
</script>

<template>
  <div class="flex flex-col gap-2 py-4">
    <div class="flex items-center gap-2">
      <input
        v-model="isEnabled"
        name="enable-lunch-break"
        class="m-0"
        type="checkbox"
      />
      <span class="text-body-main text-n-slate-12 font-medium">
        {{ t('INBOX_MGMT.BUSINESS_HOURS.LUNCH_BREAK.TITLE') }}
      </span>
    </div>
    <p class="text-label-small text-n-slate-11 m-0">
      {{ t('INBOX_MGMT.BUSINESS_HOURS.LUNCH_BREAK.HELP') }}
    </p>
    <div v-if="isEnabled" class="flex flex-col gap-1.5 mt-1">
      <div class="flex items-center gap-4">
        <NextSelect
          v-model="startTime"
          :groups="timeSlotGroups"
          :placeholder="t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
        />
        <div class="flex items-center">
          <Icon icon="i-lucide-minus size-4" />
        </div>
        <NextSelect
          v-model="endTime"
          :groups="timeSlotGroups"
          :placeholder="t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
        />
      </div>
      <span v-if="hasError" class="error text-label-small text-n-ruby-9">
        {{ t('INBOX_MGMT.BUSINESS_HOURS.LUNCH_BREAK.VALIDATION_ERROR') }}
      </span>
    </div>
  </div>
</template>
