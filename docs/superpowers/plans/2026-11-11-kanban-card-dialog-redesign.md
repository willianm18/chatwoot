# Kanban — redesign do diálogo do cartão (fase 5) — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesenhar o diálogo do cartão do Kanban no estilo Trello: barra "Adicionar", prazo em pill, UI de etiquetas (criar/editar/excluir), anexos reformulados, comentário mais visível, scroll independente e rodapé Salvar/Excluir.

**Architecture:** Quase tudo frontend. Backend só adiciona `byte_size` ao payload do anexo. Etiquetas reusam a CRUD que já existe no backend (`labels` com create/update/destroy) — falta só `updateLabel` no store/API e um `LabelPicker.vue` novo. O diálogo passa a ter altura fixa com cada coluna rolando sozinha.

**Tech Stack:** Rails jbuilder, Vue 3 `<script setup>` + Vuex, Tailwind (`n-*`), `date-fns`, `KANBAN_LABEL_PALETTE`.

## Global Constraints

- **Sem Ruby/Postgres local:** specs de backend validam só na CI; `db/schema.rb` não muda nesta fase.
- **Tailwind only** (sem CSS custom/scoped); cor dinâmica de dados via `:style` (exceção já usada).
- **Vue** Composition API `<script setup>`; PascalCase; eventos camelCase; PropTypes.
- **i18n** só no overlay `fazer-ai/locale/<locale>/kanban.json` (en, pt_BR, es); nada de string crua.
- **Namespace custom;** sem edição em arquivos do upstream nesta fase (sem schema/rota nova).
- **Commits** Conventional, `--no-verify` local. Branch `feat/kanban-card-dialog-redesign` (criada, spec commitada).
- **Prettier:** validar com cópias LF **dentro** do repo (`mkdir .tmpfmt`) — a config não resolve fora do repo.

---

## File Structure

**Backend — editado (nosso):** `_card.json.jbuilder` (só `byte_size`).
**Frontend — novo (nosso):** `routes/dashboard/kanban/components/LabelPicker.vue`.
**Frontend — editados (nossos):** `CardDialog.vue`, `CardComments.vue`, `CardAttachments.vue`,
`api/custom/kanban.js`, `store/modules/custom/kanban.js`.
**i18n:** `fazer-ai/locale/{en,pt_BR,es}/kanban.json`.
**Spec:** `spec/controllers/api/v1/accounts/custom/kanban/cards_controller_spec.rb` (byte_size no payload).

---

## Task 1: Backend — `byte_size` no anexo

**Files:**
- Modify: `app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder:16-22`
- Test: `spec/controllers/api/v1/accounts/custom/kanban/cards_controller_spec.rb`

**Interfaces:**
- Produces: cada anexo com `byte_size: number`.

- [ ] **Step 1: Adicionar byte_size**

No bloco `json.attachments`, após `json.content_type file.content_type`:

```ruby
  json.byte_size file.byte_size
```

- [ ] **Step 2: Spec (falha → CI)**

Adicionar ao `cards_controller_spec.rb`:

```ruby
it 'includes the attachment byte size in the payload' do
  card = todo.cards.create!(title: 'x', position: 0)
  card.files.attach(
    io: StringIO.new('hello'), filename: 'a.txt', content_type: 'text/plain'
  )
  get "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}",
      headers: owner.create_new_auth_token, as: :json
  returned = response.parsed_body['columns'].flat_map { |c| c['cards'] }.find { |c| c['id'] == card.id }
  expect(returned['attachments'].first['byte_size']).to eq(5)
end
```

- [ ] **Step 3: Commit**

```bash
git add app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder spec/controllers/api/v1/accounts/custom/kanban/cards_controller_spec.rb
git commit --no-verify -m "feat(kanban): expose attachment byte_size in card payload"
```

---

## Task 2: API + store — `updateLabel`

**Files:**
- Modify: `app/javascript/dashboard/api/custom/kanban.js`
- Modify: `app/javascript/dashboard/store/modules/custom/kanban.js`

**Interfaces:**
- Produces: `KanbanAPI.updateLabel(boardId, id, data)`, action `kanban/updateLabel`.

- [ ] **Step 1: API client**

Em `kanban.js`, após `createLabel`:

```js
  updateLabel(boardId, id, data) {
    return axios.patch(`${this.nested(boardId, 'labels')}/${id}`, {
      label: data,
    });
  }
```

- [ ] **Step 2: Store action**

Em `store/modules/custom/kanban.js`, após `createLabel`:

```js
  updateLabel: async ({ dispatch }, { boardId, id, ...label }) => {
    await KanbanAPI.updateLabel(boardId, id, label);
    await dispatch('fetchBoard', boardId);
  },
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/api/custom/kanban.js app/javascript/dashboard/store/modules/custom/kanban.js
git commit --no-verify -m "feat(kanban): updateLabel action and api client"
```

---

## Task 3: `LabelPicker.vue` — seletor com criar/editar/excluir

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/kanban/components/LabelPicker.vue`

**Interfaces:**
- Consumes: props `boardId`, `labels` (do quadro), `modelValue` (`number[]` = label_ids do cartão); `KANBAN_LABEL_PALETTE`; actions `kanban/createLabel`, `updateLabel`, `deleteLabel`.
- Produces: `update:modelValue` (toggle dos label_ids).

- [ ] **Step 1: Implementar o componente**

```vue
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
      <li v-for="label in labels" :key="label.id" class="flex items-center gap-1">
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

    <div v-if="editing !== null" class="flex flex-col gap-2 pt-2 border-t border-n-weak">
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
          :class="draftColor === color ? 'ring-2 ring-offset-1 ring-n-slate-11' : ''"
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
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/LabelPicker.vue
git commit --no-verify -m "feat(kanban): label picker with create/edit/delete"
```

---

## Task 4: `CardAttachments.vue` reformulado

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/CardAttachments.vue`

**Interfaces:**
- Consumes: `attachment.byte_size` (Task 1).

- [ ] **Step 1: Reescrever o componente**

```vue
<script setup>
import { ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  card: { type: Object, required: true },
});

const store = useStore();
const { t } = useI18n();
const fileInput = ref(null);

const formatSize = bytes => {
  if (!bytes && bytes !== 0) return '';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

const onPick = async event => {
  const [file] = event.target.files;
  if (!file) return;
  await store.dispatch('kanban/addAttachment', {
    boardId: props.boardId,
    cardId: props.card.id,
    file,
  });
  if (fileInput.value) fileInput.value.value = '';
};

const remove = attachment =>
  store.dispatch('kanban/removeAttachment', {
    boardId: props.boardId,
    cardId: props.card.id,
    id: attachment.id,
  });
</script>

<template>
  <div class="flex flex-col gap-2">
    <h4 class="text-xs font-medium uppercase text-n-slate-10">
      {{ t('KANBAN.ATTACHMENTS.TITLE') }}
    </h4>
    <ul v-if="card.attachments?.length" class="flex flex-col gap-2">
      <li
        v-for="attachment in card.attachments"
        :key="attachment.id"
        class="flex items-center gap-3 p-2 border rounded-lg border-n-weak bg-n-alpha-black1"
      >
        <a
          :href="attachment.file_url"
          target="_blank"
          rel="noopener noreferrer"
          class="shrink-0"
        >
          <img
            v-if="attachment.is_image"
            :src="attachment.file_url"
            :alt="attachment.filename"
            class="object-cover rounded size-9"
          />
          <span
            v-else
            class="flex items-center justify-center rounded size-9 bg-n-alpha-black2"
          >
            <Icon icon="i-lucide-file" class="size-4 text-n-slate-11" />
          </span>
        </a>
        <div class="flex-1 min-w-0">
          <a
            :href="attachment.file_url"
            target="_blank"
            rel="noopener noreferrer"
            class="block text-sm truncate text-n-slate-12 hover:underline"
          >
            {{ attachment.filename }}
          </a>
          <span class="text-xs text-n-slate-10">
            {{ formatSize(attachment.byte_size) }}
          </span>
        </div>
        <button
          class="text-xs shrink-0 text-n-slate-10 hover:text-n-ruby-11"
          @click="remove(attachment)"
        >
          {{ t('KANBAN.ATTACHMENTS.REMOVE') }}
        </button>
      </li>
    </ul>
    <button
      type="button"
      class="self-start inline-flex items-center gap-1.5 px-3 py-2 text-sm rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
      @click="fileInput.click()"
    >
      <Icon icon="i-lucide-paperclip" class="size-4" />
      {{ t('KANBAN.ATTACHMENTS.ADD') }}
    </button>
    <input ref="fileInput" type="file" class="hidden" @change="onPick" />
  </div>
</template>
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/CardAttachments.vue
git commit --no-verify -m "feat(kanban): reworked attachments list with size and add button"
```

---

## Task 5: `CardComments.vue` — composer mais visível

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/CardComments.vue`

- [ ] **Step 1: Placeholder do comentário mais escuro/visível**

Trocar o botão placeholder (o `v-else` que emite `activate`):

```vue
    <button
      v-else
      type="button"
      class="px-3 py-2.5 text-sm rounded-lg text-start text-n-slate-11 bg-n-alpha-black2 border border-n-strong hover:bg-n-alpha-black3"
      @click="emit('activate')"
    >
      {{ t('KANBAN.COMMENTS.PLACEHOLDER') }}
    </button>
```

- [ ] **Step 2: Estrutura p/ scroll independente (composer fixo + lista rolável)**

Trocar o `<template>` raiz para que o composer/placeholder fique no topo (fixo) e a
lista de comentários role abaixo:

```vue
<template>
  <div class="flex flex-col h-full gap-2 min-h-0">
    <h4 class="text-sm font-medium shrink-0 text-n-slate-12">
      {{ t('KANBAN.COMMENTS.TITLE') }}
    </h4>

    <!-- Composer fixo no topo -->
    <div class="shrink-0">
      <div v-if="active" class="flex flex-col gap-2">
        <FullEditor
          v-model="draft"
          :editor-id="`kanban-comment-${card.id}-${editorKey}`"
          :placeholder="t('KANBAN.COMMENTS.PLACEHOLDER')"
          :enabled-menu-options="ARTICLE_EDITOR_MENU_OPTIONS"
          autofocus
          class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12 [&_.ProseMirror-woot-style]:min-h-[8rem]"
        />
        <div class="flex items-center self-end gap-2">
          <button
            class="text-sm text-n-slate-10 hover:text-n-slate-12"
            @click="cancel"
          >
            {{ t('KANBAN.COMMENTS.CANCEL') }}
          </button>
          <button
            class="px-3 py-1.5 text-sm text-white rounded-lg bg-n-brand"
            @click="add"
          >
            {{ t('KANBAN.COMMENTS.SEND') }}
          </button>
        </div>
      </div>
      <button
        v-else
        type="button"
        class="w-full px-3 py-2.5 text-sm rounded-lg text-start text-n-slate-11 bg-n-alpha-black2 border border-n-strong hover:bg-n-alpha-black3"
        @click="emit('activate')"
      >
        {{ t('KANBAN.COMMENTS.PLACEHOLDER') }}
      </button>
    </div>

    <!-- Lista rolável -->
    <ul
      v-if="sortedComments.length"
      class="flex flex-col flex-1 min-h-0 gap-2 overflow-y-auto"
    >
      <li
        v-for="comment in sortedComments"
        :key="comment.id"
        class="flex flex-col gap-0.5 p-2 rounded-lg bg-n-alpha-black1"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-xs font-medium text-n-slate-11">
            {{ comment.author_name }}
          </span>
          <div class="flex items-center gap-2 shrink-0">
            <span class="text-xs text-n-slate-10">
              {{ formatStamp(comment.created_at) }}
            </span>
            <button
              v-if="canManage(comment)"
              class="text-xs text-n-ruby-11"
              @click="remove(comment)"
            >
              {{ t('KANBAN.COMMENTS.DELETE') }}
            </button>
          </div>
        </div>
        <!-- eslint-disable-next-line vue/no-v-html -->
        <div
          class="text-sm prose-sm text-n-slate-12 max-w-none"
          v-html="formatMessage(comment.content, false, false)"
        />
      </li>
    </ul>
    <p v-else class="text-xs text-n-slate-10 shrink-0">
      {{ t('KANBAN.COMMENTS.EMPTY') }}
    </p>
  </div>
</template>
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/CardComments.vue
git commit --no-verify -m "feat(kanban): visible comment composer and scrollable comment list"
```

---

## Task 6: `CardDialog.vue` — barra de ação, prazo pill, LabelPicker, scroll, rodapé

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue`

**Interfaces:**
- Consumes: `LabelPicker.vue`, `cardDateFormat` (`formatDueDate`, `isOverdue`).

- [ ] **Step 1: Imports + estado**

No `<script setup>`, adicionar:

```js
import LabelPicker from './LabelPicker.vue';
import { formatDueDate, isOverdue } from '../cardDateFormat';
```

Adicionar um ref para o popover de etiquetas e um para o input de data:

```js
const showLabelPicker = ref(false);
```

Remover o `toggleLabel` (agora o `LabelPicker` cuida do toggle via v-model). A barra
de ação usa `showDueDate`/`showLabelPicker` já existentes/novos; o anexo é acionado
por um método exposto pelo `CardAttachments` — para simplicidade, o botão "Anexo" da
barra apenas rola/foca a seção de anexos: trocar por acionar o input escondido via um
ref. Como `CardAttachments` encapsula o input, o botão "Anexo" da barra fica como um
atalho visual que **revela** a seção (ela já está sempre visível), então o botão
"Anexo" na barra pode simplesmente abrir o seletor nativo reutilizando um
`attachmentsRef`:

```js
const attachmentsRef = ref(null);
```

e expor um método `openFilePicker` no `CardAttachments` (ver Step 5).

- [ ] **Step 2: Cabeçalho + barra de ação (template)**

Logo após o bloco do título (`<div class="flex flex-col gap-2 mb-4">…</div>`),
adicionar a barra de ação:

```vue
    <div class="flex flex-wrap gap-2 mb-4">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
        @click="showLabelPicker = !showLabelPicker"
      >
        <Icon icon="i-lucide-tag" class="size-3.5" />
        {{ t('KANBAN.ACTIONS.LABEL') }}
      </button>
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
        @click="showDueDate = true"
      >
        <Icon icon="i-lucide-calendar" class="size-3.5" />
        {{ t('KANBAN.ACTIONS.DATE') }}
      </button>
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
        @click="attachmentsRef?.openFilePicker()"
      >
        <Icon icon="i-lucide-paperclip" class="size-3.5" />
        {{ t('KANBAN.ACTIONS.ATTACHMENT') }}
      </button>
    </div>
```

- [ ] **Step 3: Seção Etiquetas → LabelPicker num popover**

Trocar a seção de etiquetas (os botões soltos) por:

```vue
        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.LABELS') }}
          </h4>
          <div class="flex flex-wrap items-center gap-2">
            <span
              v-for="label in labels.filter(l => form.label_ids.includes(l.id))"
              :key="label.id"
              class="h-6 px-2 text-xs leading-6 text-white rounded-full"
              :style="{ backgroundColor: label.color }"
            >
              {{ label.name }}
            </span>
            <div class="relative">
              <button
                type="button"
                class="flex items-center justify-center rounded-full size-6 bg-n-alpha-black2 text-n-slate-11 hover:bg-n-alpha-black3"
                @click="showLabelPicker = !showLabelPicker"
              >
                <Icon icon="i-lucide-plus" class="size-3.5" />
              </button>
              <div
                v-if="showLabelPicker"
                v-on-click-outside="() => (showLabelPicker = false)"
                class="absolute z-10 p-2 mt-1 border rounded-lg shadow-lg bg-n-solid-1 border-n-weak"
              >
                <LabelPicker
                  v-model="form.label_ids"
                  :board-id="boardId"
                  :labels="labels"
                />
              </div>
            </div>
          </div>
        </section>
```

- [ ] **Step 4: Prazo em pill**

Trocar a seção de prazo por:

```vue
        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.DUE_DATE') }}
          </h4>
          <input
            v-if="showDueDate && !form.due_date"
            v-model="form.due_date"
            type="date"
            class="self-start px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
          />
          <span
            v-else-if="form.due_date"
            class="inline-flex items-center self-start gap-2 px-3 py-1.5 text-sm font-medium rounded-full"
            :class="
              isOverdue(form.due_date)
                ? 'bg-n-ruby-3 text-n-ruby-11'
                : 'bg-n-alpha-black2 text-n-slate-11'
            "
          >
            <Icon icon="i-lucide-calendar" class="size-3.5" />
            {{ formatDueDate(form.due_date) }}
            <button
              type="button"
              class="opacity-70 hover:opacity-100"
              :title="t('KANBAN.CARD.CLEAR_DUE_DATE')"
              @click="clearDueDate"
            >
              <Icon icon="i-lucide-x" class="size-3.5" />
            </button>
          </span>
          <button
            v-else
            type="button"
            class="self-start inline-flex items-center gap-1.5 px-3 py-2 text-sm rounded-lg text-n-slate-11 bg-n-alpha-black2 hover:bg-n-alpha-black3"
            @click="showDueDate = true"
          >
            <Icon icon="i-lucide-calendar" class="size-4" />
            {{ t('KANBAN.CARD.SET_DUE_DATE') }}
          </button>
        </section>
```

(Quando `form.due_date` existe, mostra a pill; limpar volta ao botão. `showDueDate`
revela o `<input date>` apenas enquanto não há data.)

- [ ] **Step 5: `CardAttachments` expõe `openFilePicker`; `ref` no uso**

Em `CardAttachments.vue`, adicionar no `<script setup>`:

```js
const openFilePicker = () => fileInput.value?.click();
defineExpose({ openFilePicker });
```

Em `CardDialog.vue`, no uso do `CardAttachments`, adicionar o ref:

```vue
        <CardAttachments
          v-if="liveCard"
          ref="attachmentsRef"
          :board-id="boardId"
          :card="liveCard"
        />
```

- [ ] **Step 6: Scroll independente + rodapé**

Trocar o corpo (`<div class="flex flex-col gap-6 md:flex-row">…`) para altura fixa com
colunas roláveis, e o rodapé:

- O container do corpo: `class="flex flex-col flex-1 min-h-0 gap-6 md:flex-row"`.
- Coluna esquerda (cartão): adicionar `md:overflow-y-auto md:min-h-0` e tirar o
  `md:pe-6` nada muda; manter `flex-1 min-w-0`.
- Coluna direita (comentários): `class="flex flex-col min-w-0 min-h-0 shrink-0 md:w-96"`
  (o `CardComments` já é `h-full` com lista rolável — Task 5).
- Rodapé (dentro da coluna esquerda, no fim): trocar por:

```vue
        <div
          class="flex items-center justify-between pt-3 mt-2 border-t shrink-0 border-n-weak"
        >
          <button
            v-if="card"
            type="button"
            class="inline-flex items-center gap-1.5 text-sm text-n-ruby-11 hover:text-n-ruby-10"
            @click="remove"
          >
            <Icon icon="i-lucide-trash-2" class="size-4" />
            {{ t('KANBAN.CARD.DELETE') }}
          </button>
          <button
            type="button"
            class="px-4 py-2 text-sm font-medium text-white rounded-lg ms-auto bg-n-brand hover:opacity-90"
            @click="save"
          >
            {{ t('KANBAN.CARD.SAVE') }}
          </button>
        </div>
```

Para o diálogo ter altura fixa, o conteúdo raiz do slot passa a ser
`class="flex flex-col h-full"` envolvendo cabeçalho (shrink-0) + barra de ação
(shrink-0) + corpo (flex-1 min-h-0). Ajustar o `<template>` para esse envelope.

- [ ] **Step 7: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue app/javascript/dashboard/routes/dashboard/kanban/components/CardAttachments.vue
git commit --no-verify -m "feat(kanban): trello-style action bar, due-date pill, label popover, split scroll"
```

---

## Task 7: i18n (en, pt_BR, es)

**Files:**
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/kanban.json`

**Interfaces:**
- Produces: `KANBAN.ACTIONS.{LABEL,DATE,ATTACHMENT}`, `KANBAN.LABELS.{NEW,EDIT,DELETE,NAME}`, `KANBAN.ATTACHMENTS.ADD`.

- [ ] **Step 1: Adicionar as chaves (3 locais)**

`en` — dentro de `KANBAN`:
```json
"ACTIONS": { "LABEL": "Label", "DATE": "Date", "ATTACHMENT": "Attachment" },
"LABELS": { "NEW": "Create label", "EDIT": "Edit label", "DELETE": "Delete label", "NAME": "Label name" }
```
e dentro de `ATTACHMENTS`: `"ADD": "Add attachment"`.

`pt_BR`:
```json
"ACTIONS": { "LABEL": "Etiqueta", "DATE": "Data", "ATTACHMENT": "Anexo" },
"LABELS": { "NEW": "Criar etiqueta", "EDIT": "Editar etiqueta", "DELETE": "Excluir etiqueta", "NAME": "Nome da etiqueta" }
```
`ATTACHMENTS.ADD`: `"Adicionar anexo"`.

`es`:
```json
"ACTIONS": { "LABEL": "Etiqueta", "DATE": "Fecha", "ATTACHMENT": "Adjunto" },
"LABELS": { "NEW": "Crear etiqueta", "EDIT": "Editar etiqueta", "DELETE": "Eliminar etiqueta", "NAME": "Nombre de la etiqueta" }
```
`ATTACHMENTS.ADD`: `"Agregar adjunto"`.

- [ ] **Step 2: Validar JSON**

Run: `node -e "['en','pt_BR','es'].forEach(l=>JSON.parse(require('fs').readFileSync('app/javascript/dashboard/i18n/fazer-ai/locale/'+l+'/kanban.json')))"`
Expected: sem erro.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/i18n/fazer-ai/locale/en/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/es/kanban.json
git commit --no-verify -m "feat(kanban): i18n for action bar, labels and add attachment"
```

---

## Task 8: lint + registro

- [ ] **Step 1: Prettier (LF, dentro do repo) + eslint** dos arquivos editados; corrigir linhas longas.
- [ ] **Step 2: Registrar a Fase 5** no `.claude/CLAUDE.md` (bloco do Kanban): redesign do diálogo (barra de ação, prazo pill, `LabelPicker` com CRUD de etiqueta, anexos reformulados com `byte_size`, composer visível, scroll independente, rodapé). Só `_card.json.jbuilder` mexe no backend. Design/plano em `docs/superpowers/`.
- [ ] **Step 3: Commit**

```bash
git add .claude/CLAUDE.md
git commit --no-verify -m "docs(kanban): record phase 5 (card dialog redesign) in fork notes"
```

---

## Self-Review

- **Spec coverage:** byte_size (T1), updateLabel (T2), LabelPicker CRUD (T3), anexos (T4), composer+scroll comentários (T5), barra de ação/prazo pill/label popover/scroll/rodapé (T6), i18n (T7), registro (T8). Tudo coberto.
- **Placeholders:** nenhum.
- **Type consistency:** `updateLabel({boardId,id,name,color})` igual em T2 e T3; `LabelPicker` v-model `form.label_ids` (number[]) consistente; `byte_size` (number) de T1 usado em T4; `openFilePicker` exposto em T4/T6.
- **Edição upstream:** nenhuma (sem schema/rota).
