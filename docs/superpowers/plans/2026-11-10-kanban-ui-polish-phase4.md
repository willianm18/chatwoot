# Kanban UI polish (fase 4) — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar cor por coluna (paleta da "cor por caixa"), filtros compactos no cabeçalho e editor rico com imagem inline na descrição e nos comentários do Kanban.

**Architecture:** Cor por coluna = 1 coluna nova `custom_kanban_columns.custom_color` validada contra `Custom::InboxCustomColor::PALETTE`, pintando o cabeçalho via `:style` (exceção dinâmica já usada no fork). Editor rico = reuso do `FullEditor.vue` (ProseMirror, já faz colar/upload de imagem inline → `/upload` → markdown `![](url)`) com exibição via `MessageFormatter`; os campos `description`/`content` (text) passam a guardar markdown, sem migration. Filtros = só restyle do cabeçalho.

**Tech Stack:** Rails (ActiveRecord, jbuilder), Vue 3 `<script setup>` + Vuex, Tailwind (tokens `n-*`), `FullEditor.vue`/`@chatwoot/prosemirror-schema`, `shared/helpers/MessageFormatter` (MarkdownIt), `InboxColorPicker.vue`, `INBOX_COLOR_PALETTE`.

## Global Constraints

- **Sem Ruby/Postgres local:** specs de backend validam **só na CI** (`run_foss_spec.yml`). `db/schema.rb` editado à mão; dev com Ruby roda `bundle exec rails db:migrate` e confere o schema regenerado antes do merge.
- **Tailwind only:** sem CSS custom/scoped; cor dinâmica de dados via `:style` (exceção já usada nas pills de etiqueta e na cor de caixa).
- **Sem SQL cru;** migrations idempotentes com `unless column_exists?`; criar com timestamp real.
- **Vue:** Composition API `<script setup>`; PascalCase; eventos camelCase; PropTypes.
- **i18n:** nada de string crua; chaves nossas só no overlay `fazer-ai/locale/<locale>/kanban.json` em en, pt_BR e es.
- **Namespace custom;** edição em upstream só `db/schema.rb`. Registrar em "Mudanças nossas".
- **Commits:** Conventional Commits, `--no-verify` local (husky roda `bundle`, ausente). Branch: `feat/kanban-ui-polish-phase4` (já criada, spec commitada).
- **Markdown retrocompatível:** texto puro antigo em `description`/`content` é markdown válido; nenhuma migração de dados.

---

## File Structure

**Backend — novos:** migration `...add_custom_color_to_kanban_columns`.
**Backend — editados (nossos):** `app/models/custom/kanban/column.rb`, `columns_controller.rb`, `_column.json.jbuilder`.
**Backend — upstream:** `db/schema.rb`.
**Frontend — editados (nossos):** `components/KanbanColumn.vue`, `BoardView.vue`, `components/CardDialog.vue`, `components/CardComments.vue`.
**Frontend — reuso (sem editar):** `components/custom/InboxColorPicker.vue`, `components/widgets/WootWriter/FullEditor.vue`, `shared/composables/useMessageFormatter.js`, `constants/editor.js` (`ARTICLE_EDITOR_MENU_OPTIONS`), `constants/customInboxColors.js`.
**i18n:** `fazer-ai/locale/{en,pt_BR,es}/kanban.json`.
**Specs:** `spec/models/custom/kanban/column_spec.rb`, `spec/controllers/api/v1/accounts/custom/kanban/columns_controller_spec.rb` (criar se não existir).

---

## Task 1: Migration + schema — `custom_color` na coluna

**Files:**
- Create: `db/migrate/20261110160000_add_custom_color_to_kanban_columns.rb`
- Modify: `db/schema.rb`

**Interfaces:**
- Produces: `custom_kanban_columns.custom_color` (string, nullable).

- [ ] **Step 1: Migration**

```ruby
# db/migrate/20261110160000_add_custom_color_to_kanban_columns.rb
# [fazer.ai fork] Optional per-column color (shares the inbox color palette).
class AddCustomColorToKanbanColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :custom_kanban_columns, :custom_color, :string unless column_exists?(:custom_kanban_columns, :custom_color)
  end
end
```

- [ ] **Step 2: Editar `db/schema.rb`**

No bloco `create_table "custom_kanban_columns"`, adicionar após `t.integer "position"...`:

```ruby
    t.string "custom_color"
```

Atualizar a versão no topo: `ActiveRecord::Schema[7.2].define(version: 2026_11_10_160000) do`.

- [ ] **Step 3: Commit**

```bash
git add db/migrate/20261110160000_add_custom_color_to_kanban_columns.rb db/schema.rb
git commit --no-verify -m "feat(kanban): add custom_color column to kanban columns"
```

---

## Task 2: Model + controller + payload da cor

**Files:**
- Modify: `app/models/custom/kanban/column.rb`
- Modify: `app/controllers/api/v1/accounts/custom/kanban/columns_controller.rb:35`
- Modify: `app/views/api/v1/accounts/custom/kanban/boards/_column.json.jbuilder`
- Test: `spec/models/custom/kanban/column_spec.rb`, `spec/controllers/api/v1/accounts/custom/kanban/columns_controller_spec.rb`

**Interfaces:**
- Consumes: `Custom::InboxCustomColor::PALETTE`.
- Produces: coluna valida `custom_color` na paleta ou nil; controller aceita `:custom_color`; payload traz `custom_color`.

- [ ] **Step 1: Spec do model (falha → CI)**

```ruby
# spec/models/custom/kanban/column_spec.rb
require 'rails_helper'

RSpec.describe Custom::Kanban::Column do
  let(:account) { create(:account) }
  let(:board) { Custom::Kanban::Board.create!(account: account, name: 'B') }

  it 'accepts a color from the palette' do
    column = board.columns.new(name: 'To do', custom_color: Custom::InboxCustomColor::PALETTE.first)
    expect(column).to be_valid
  end

  it 'accepts a nil color' do
    expect(board.columns.new(name: 'To do', custom_color: nil)).to be_valid
  end

  it 'rejects a color outside the palette' do
    column = board.columns.new(name: 'To do', custom_color: '#123456')
    expect(column).not_to be_valid
    expect(column.errors[:custom_color]).to be_present
  end
end
```

- [ ] **Step 2: Validação no model**

Em `app/models/custom/kanban/column.rb`, após `validates :name, presence: true`:

```ruby
  validates :custom_color, inclusion: { in: Custom::InboxCustomColor::PALETTE }, allow_nil: true
```

- [ ] **Step 3: Controller permite `custom_color`**

Em `columns_controller.rb`, trocar `column_params`:

```ruby
  def column_params
    params.require(:column).permit(:name, :custom_color)
  end
```

- [ ] **Step 4: Payload**

Em `_column.json.jbuilder`, adicionar ao final:

```ruby
json.custom_color column.custom_color
```

- [ ] **Step 5: Spec do controller (falha → CI)**

```ruby
# spec/controllers/api/v1/accounts/custom/kanban/columns_controller_spec.rb
require 'rails_helper'

RSpec.describe 'Kanban columns API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'B', created_by_id: owner.id)
    b.members.create!(user: owner)
    b
  end
  let!(:column) { board.columns.create!(name: 'To do', position: 0) }

  it 'updates the column color' do
    color = Custom::InboxCustomColor::PALETTE.first
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/columns/#{column.id}",
          params: { column: { custom_color: color } }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(column.reload.custom_color).to eq(color)
    expect(response.parsed_body['custom_color']).to eq(color)
  end
end
```

- [ ] **Step 6: Commit**

```bash
git add app/models/custom/kanban/column.rb app/controllers/api/v1/accounts/custom/kanban/columns_controller.rb app/views/api/v1/accounts/custom/kanban/boards/_column.json.jbuilder spec/models/custom/kanban/column_spec.rb spec/controllers/api/v1/accounts/custom/kanban/columns_controller_spec.rb
git commit --no-verify -m "feat(kanban): validate and persist per-column custom_color"
```

---

## Task 3: `KanbanColumn.vue` — faixa tingida + seletor de cor

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanColumn.vue`

**Interfaces:**
- Consumes: `kanban/updateColumn` (store, já existe), `InboxColorPicker.vue`, `INBOX_COLOR_PALETTE` (indireto), `vOnClickOutside`.
- Produces: cabeçalho da coluna pintado quando `column.custom_color`; seletor emite `updateColumn` com `custom_color`.

- [ ] **Step 1: Script — import do picker + estado + handler**

No `<script setup>` de `KanbanColumn.vue`, adicionar imports e lógica:

```js
import { ref, watch, computed } from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import InboxColorPicker from 'dashboard/components/custom/InboxColorPicker.vue';
```

(Mantém os imports existentes `draggable`, `useStore`, `useI18n`, `Icon`, `KanbanCard`.)

Após o `const { t } = useI18n();`:

```js
const showColorPicker = ref(false);

// Tinted header band when a color is set (dynamic data color → inline style,
// the accepted exception used by label pills and the per-inbox color).
const headerStyle = computed(() =>
  props.column.custom_color
    ? {
        backgroundColor: `${props.column.custom_color}26`,
        borderBottom: `1px solid ${props.column.custom_color}`,
      }
    : {}
);

const setColor = color => {
  showColorPicker.value = false;
  store.dispatch('kanban/updateColumn', {
    boardId: props.boardId,
    id: props.column.id,
    custom_color: color,
  });
};
```

- [ ] **Step 2: Template — aplicar faixa e botão de cor no cabeçalho**

Trocar o bloco do cabeçalho (`<div class="flex items-center gap-1">...`) por:

```vue
    <div
      class="flex items-center gap-1 px-1 py-0.5 -mx-1 -mt-1 rounded-t-xl"
      :style="headerStyle"
    >
      <input
        v-model="name"
        class="flex-1 min-w-0 px-1 text-sm font-medium bg-transparent rounded text-n-slate-12 hover:bg-n-alpha-black2 focus:bg-n-alpha-black2"
        @keyup.enter="renameColumn"
        @blur="renameColumn"
      />
      <span
        class="px-1.5 text-xs rounded-full text-n-slate-10 bg-n-alpha-black2"
      >
        {{ column.cards.length }}
      </span>
      <div class="relative shrink-0">
        <button
          class="text-n-slate-10 hover:text-n-slate-12"
          :title="t('KANBAN.COLUMN.COLOR')"
          @click="showColorPicker = !showColorPicker"
        >
          <Icon icon="i-lucide-palette" class="size-3.5" />
        </button>
        <div
          v-if="showColorPicker"
          v-on-click-outside="() => (showColorPicker = false)"
          class="absolute z-10 p-2 mt-1 border rounded-lg shadow-lg ltr:right-0 rtl:left-0 bg-n-solid-1 border-n-weak"
        >
          <InboxColorPicker
            :model-value="column.custom_color ?? null"
            @update:model-value="setColor"
          />
        </div>
      </div>
      <button
        class="shrink-0 text-n-slate-10 hover:text-n-slate-12"
        :title="t('KANBAN.NEW_CARD')"
        @click="$emit('addCard', column)"
      >
        <Icon icon="i-lucide-plus" class="size-3.5" />
      </button>
      <button
        class="shrink-0 text-n-slate-10 hover:text-n-ruby-11"
        :title="t('KANBAN.COLUMN.DELETE')"
        @click="deleteColumn"
      >
        <Icon icon="i-lucide-trash-2" class="size-3.5" />
      </button>
    </div>
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/KanbanColumn.vue
git commit --no-verify -m "feat(kanban): tinted column header and per-column color picker"
```

---

## Task 4: `BoardView.vue` — filtros compactos

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/BoardView.vue`

**Interfaces:**
- Produces: cabeçalho numa linha só com controles compactos; nenhuma mudança de lógica de filtragem.

- [ ] **Step 1: Restyle do header no template**

Trocar o `<header>` atual por uma linha compacta. Os `<select>` continuam nativos mas estilizados pequenos; o botão "Meus cards" e "Membros" ficam compactos:

```vue
    <header
      class="flex flex-wrap items-center gap-2 px-4 py-2.5 border-b border-n-weak"
    >
      <h1 class="text-base font-medium text-n-slate-12 me-1">{{ board.name }}</h1>
      <select
        v-model="assigneeFilter"
        class="px-2 py-1 text-xs border rounded-lg cursor-pointer border-n-weak bg-n-alpha-black1 text-n-slate-11 hover:border-n-slate-6"
      >
        <option :value="null">{{ t('KANBAN.FILTERS.ASSIGNEE') }}</option>
        <option
          v-for="member in members"
          :key="member.user_id"
          :value="member.user_id"
        >
          {{ member.name }}
        </option>
      </select>
      <select
        v-model="labelFilter"
        class="px-2 py-1 text-xs border rounded-lg cursor-pointer border-n-weak bg-n-alpha-black1 text-n-slate-11 hover:border-n-slate-6"
      >
        <option :value="null">{{ t('KANBAN.FILTERS.LABEL') }}</option>
        <option v-for="label in labels" :key="label.id" :value="label.id">
          {{ label.name }}
        </option>
      </select>
      <button
        class="px-2 py-1 text-xs border rounded-lg"
        :class="
          onlyMine
            ? 'border-n-brand text-n-brand'
            : 'border-n-weak text-n-slate-11 hover:border-n-slate-6'
        "
        @click="onlyMine = !onlyMine"
      >
        {{ t('KANBAN.FILTERS.MY_CARDS') }}
      </button>
      <button
        v-if="assigneeFilter || labelFilter || onlyMine"
        class="text-xs text-n-slate-10 hover:text-n-slate-12"
        @click="clearFilters"
      >
        {{ t('KANBAN.FILTERS.CLEAR') }}
      </button>
      <Button
        v-if="isOwner"
        sm
        ghost
        slate
        :label="t('KANBAN.MEMBERS')"
        class="ms-auto"
        @click="membersDialog.open()"
      />
    </header>
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/BoardView.vue
git commit --no-verify -m "feat(kanban): compact single-row filter bar"
```

---

## Task 5: `CardDialog.vue` — descrição em editor rico

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue`

**Interfaces:**
- Consumes: `FullEditor.vue`, `ARTICLE_EDITOR_MENU_OPTIONS`.
- Produces: descrição editada como markdown (com imagens inline) em `form.description`.

- [ ] **Step 1: Imports**

No `<script setup>` de `CardDialog.vue`, adicionar:

```js
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import { ARTICLE_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
```

- [ ] **Step 2: Trocar o `<textarea>` da descrição pelo editor**

Substituir o bloco da descrição:

```vue
        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.DESCRIPTION') }}
          </h4>
          <FullEditor
            v-model="form.description"
            :editor-id="`kanban-desc-${card?.id ?? 'new'}`"
            :placeholder="t('KANBAN.CARD.DESCRIPTION')"
            :enabled-menu-options="ARTICLE_EDITOR_MENU_OPTIONS"
            :autofocus="false"
            class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
          />
        </section>
```

(O `FullEditor` emite `update:modelValue`, então `v-model` funciona. Markdown fica em `form.description`; o `save` já envia `...form.value`.)

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue
git commit --no-verify -m "feat(kanban): rich text description with inline images"
```

---

## Task 6: `CardComments.vue` — editor no input + markdown na exibição

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/CardComments.vue`

**Interfaces:**
- Consumes: `FullEditor.vue`, `ARTICLE_EDITOR_MENU_OPTIONS`, `useMessageFormatter`.
- Produces: comentários enviados como markdown; comentários existentes renderizados como HTML.

- [ ] **Step 1: Imports + formatter + reset do editor**

No `<script setup>`, adicionar:

```js
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import { ARTICLE_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

const { formatMessage } = useMessageFormatter();
const editorKey = ref(0); // bump to reset the editor after sending
```

Trocar o `add` para resetar o editor:

```js
const add = async () => {
  if (!draft.value.trim()) return;
  await store.dispatch('kanban/createComment', {
    boardId: props.boardId,
    cardId: props.card.id,
    content: draft.value.trim(),
  });
  draft.value = '';
  editorKey.value += 1;
};
```

- [ ] **Step 2: Template — render markdown + editor no input**

Trocar o parágrafo do comentário:

```vue
        <div
          class="prose-sm text-sm text-n-slate-12 max-w-none"
          v-html="formatMessage(comment.content, false, false)"
        />
```

(O `MessageFormatter` devolve HTML sanitizado; `v-html` é seguro aqui.)

Trocar o input do rodapé pelo editor + botão:

```vue
    <div class="flex flex-col gap-2">
      <FullEditor
        v-model="draft"
        :editor-id="`kanban-comment-${card.id}-${editorKey}`"
        :placeholder="t('KANBAN.COMMENTS.PLACEHOLDER')"
        :enabled-menu-options="ARTICLE_EDITOR_MENU_OPTIONS"
        :autofocus="false"
        class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
      />
      <button
        class="self-end px-3 py-1.5 text-sm text-white rounded-lg bg-n-brand"
        @click="add"
      >
        {{ t('KANBAN.COMMENTS.SEND') }}
      </button>
    </div>
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/CardComments.vue
git commit --no-verify -m "feat(kanban): rich text comments with inline images"
```

---

## Task 7: i18n (en, pt_BR, es)

**Files:**
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/kanban.json`

**Interfaces:**
- Produces: chave `KANBAN.COLUMN.COLOR`.

- [ ] **Step 1: Adicionar a chave nos três locais**

Dentro do objeto `COLUMN` (ao lado de `DELETE`/`DELETE_CONFIRM`):

`en`: `"COLOR": "Column color"`
`pt_BR`: `"COLOR": "Cor da coluna"`
`es`: `"COLOR": "Color de la columna"`

(O "sem cor" do picker reaproveita `INBOX_MGMT.CUSTOM_COLOR.NONE`, que já existe.)

- [ ] **Step 2: Validar JSON**

Run: `node -e "['en','pt_BR','es'].forEach(l=>JSON.parse(require('fs').readFileSync('app/javascript/dashboard/i18n/fazer-ai/locale/'+l+'/kanban.json')))"`
Expected: sem erro.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/i18n/fazer-ai/locale/en/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/es/kanban.json
git commit --no-verify -m "feat(kanban): i18n for column color label"
```

---

## Task 8: lint + registro da mudança

**Files:**
- Modify: `.claude/CLAUDE.md`

- [ ] **Step 1: Lint do frontend**

Run: `npx prettier --check` nas cópias LF dos arquivos editados (ou confiar na CI — gotcha CRLF no Windows). Garantir que nenhuma linha de classe passe de 80 colunas.

- [ ] **Step 2: Registrar no `.claude/CLAUDE.md`**

No bloco do Kanban em "Mudanças nossas", anexar a Fase 4: cor por coluna (`custom_color`, paleta reusada), filtros compactos, editor rico (`FullEditor`) com imagem inline na descrição e nos comentários (markdown nos campos `text`, sem migration), exibição via `MessageFormatter`. Listar arquivos e o schema editado. Apontar spec/plano em `docs/superpowers/`.

- [ ] **Step 3: Commit**

```bash
git add .claude/CLAUDE.md
git commit --no-verify -m "docs(kanban): record phase 4 (colors, filters, rich editor) in fork notes"
```

---

## Self-Review

- **Spec coverage:** cor por coluna (T1–T3), filtros compactos (T4), editor descrição (T5), editor+render comentários (T6), i18n (T7), registro (T8). Tudo coberto.
- **Placeholders:** nenhum — código completo em cada passo.
- **Type consistency:** `custom_color` (string/nil) consistente entre migration (T1), model/controller/payload (T2) e front (`column.custom_color`, T3). `FullEditor` com `v-model`/`editor-id`/`enabled-menu-options`/`autofocus` idêntico em T5 e T6. `formatMessage(content, false, false)` (T6) bate com a assinatura do `useMessageFormatter`.
- **Edição upstream:** só `db/schema.rb`.
