# Kanban — refinamento visual + múltiplos responsáveis — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao Kanban nativo um visual estilo Trello (card com pills, avatares, badge de prazo; modal largo de duas colunas) e substituir o responsável único por múltiplos responsáveis restritos aos membros do quadro.

**Architecture:** Múltiplos responsáveis via tabela de junção `custom_kanban_card_assignees` (mesmo padrão de `card_labels`). O payload do board passa a embarcar a lista de membros (com avatar) e cada card passa a mandar `assignee_ids`; o frontend resolve id → membro. Validação de pertencimento no model e no controller.

**Tech Stack:** Rails (ActiveRecord, jbuilder), Vue 3 `<script setup>` + Vuex, Tailwind (tokens `n-*`), `date-fns`, componentes `components-next` (`Dialog`, `Avatar`).

## Global Constraints

- **Sem Ruby/Postgres local:** specs de backend validam **só na CI** (`run_foss_spec.yml`). `db/schema.rb` é editado à mão; um dev com Ruby roda `bundle exec rails db:migrate` e confere que o schema regenerado é idêntico antes do merge.
- **Tailwind only:** sem CSS custom, sem scoped CSS, sem inline style; só classes utilitárias e tokens de `tailwind.config.js` (`n-*`).
- **Sem SQL cru:** queries e data migrations em ActiveRecord (`where`, `find_each`, `find_or_create_by!`). Nada de `execute`/heredoc SQL.
- **Migrations idempotentes:** guardas `unless table_exists?` / `if column_exists?`. Criar com timestamp real (`bundle exec rails g migration`) — aqui o timestamp é escrito à mão só no schema porque não há Ruby local; o nome do arquivo usa um timestamp real coerente.
- **Vue:** Composition API com `<script setup>`; componentes PascalCase; eventos camelCase; PropTypes declarados.
- **i18n:** nada de string crua; chaves nossas só no overlay `app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/kanban.json` em **en, pt_BR e es** (nunca no locale do upstream).
- **Namespace custom:** código novo em `Custom::Kanban::*` / arquivos `custom`. Edições em arquivos do upstream só o schema (que a feature já edita) — registrar em "Mudanças nossas" no `.claude/CLAUDE.md`.
- **Commits:** Conventional Commits; commitar com `--no-verify` localmente (o husky roda `bundle`, que não existe aqui). Branch: `feat/kanban-visual-refresh` (já criada).
- **Acesso:** quadros são privados aos membros; o dono é sempre membro. Logo "responsável deve ser membro do quadro" já cobre o dono.

---

## File Structure

**Backend — novos:**
- `app/models/custom/kanban/card_assignee.rb` — join card ↔ user.
- `db/migrate/20261110XXXXXX_add_card_assignees_to_kanban.rb` — tabela + backfill + drop da coluna antiga.

**Backend — editados (nossos):**
- `app/models/custom/kanban/card.rb` — troca `assignee` por `assignees` (through).
- `app/controllers/api/v1/accounts/custom/kanban/cards_controller.rb` — `assignee_ids` + validação de pertencimento.
- `app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder` — `assignee_ids`.
- `app/views/api/v1/accounts/custom/kanban/boards/show.json.jbuilder` — embarca `members` + eager-load de `assignees`.

**Backend — editado (upstream):**
- `db/schema.rb` — nova tabela, nova versão, remoção da coluna `assignee_id` de `custom_kanban_cards`.

**Frontend — novos:**
- `app/javascript/dashboard/routes/dashboard/kanban/cardDateFormat.js` — formata/compara prazo.
- `app/javascript/dashboard/routes/dashboard/kanban/components/AssigneePicker.vue` — seletor múltiplo de membros.

**Frontend — editados (nossos):**
- `components/KanbanCard.vue`, `components/CardDialog.vue`, `components/KanbanColumn.vue`, `BoardView.vue`.

**i18n (nosso overlay):**
- `fazer-ai/locale/{en,pt_BR,es}/kanban.json`.

**Specs:**
- `spec/models/custom/kanban/card_spec.rb` (ou adiciona), `spec/requests/api/v1/accounts/custom/kanban/cards_spec.rb`.
- `app/javascript/.../kanban/components/specs/KanbanCard.spec.js`, `cardDateFormat.spec.js`.

---

## Task 1: Migration + schema — tabela de responsáveis

**Files:**
- Create: `db/migrate/20261110120000_add_card_assignees_to_kanban.rb`
- Modify: `db/schema.rb` (tabela `custom_kanban_cards`, versão, nova tabela)

**Interfaces:**
- Produces: tabela `custom_kanban_card_assignees(custom_kanban_card_id, user_id, timestamps)`, índice único `[custom_kanban_card_id, user_id]`; coluna `custom_kanban_cards.assignee_id` removida.

- [ ] **Step 1: Escrever a migration**

```ruby
# db/migrate/20261110120000_add_card_assignees_to_kanban.rb
# [fazer.ai fork] Multiple assignees per Kanban card. Replaces the single
# custom_kanban_cards.assignee_id with a join table, backfilling existing values.
class AddCardAssigneesToKanban < ActiveRecord::Migration[7.1]
  def up
    unless table_exists?(:custom_kanban_card_assignees)
      create_table :custom_kanban_card_assignees do |t|
        t.bigint :custom_kanban_card_id, null: false
        t.bigint :user_id, null: false
        t.timestamps
      end
      add_index :custom_kanban_card_assignees, :custom_kanban_card_id,
                name: 'index_kanban_card_assignees_on_card'
      add_index :custom_kanban_card_assignees, %i[custom_kanban_card_id user_id],
                unique: true, name: 'index_kanban_card_assignees_on_card_and_user'
    end

    return unless column_exists?(:custom_kanban_cards, :assignee_id)

    cards = Class.new(ActiveRecord::Base) { self.table_name = 'custom_kanban_cards' }
    joins = Class.new(ActiveRecord::Base) { self.table_name = 'custom_kanban_card_assignees' }
    cards.where.not(assignee_id: nil).find_each do |card|
      joins.find_or_create_by!(custom_kanban_card_id: card.id, user_id: card.assignee_id)
    end

    remove_column :custom_kanban_cards, :assignee_id
  end

  def down
    add_column :custom_kanban_cards, :assignee_id, :bigint unless column_exists?(:custom_kanban_cards, :assignee_id)
    drop_table :custom_kanban_card_assignees if table_exists?(:custom_kanban_card_assignees)
  end
end
```

- [ ] **Step 2: Editar `db/schema.rb` à mão**

Remover a linha `t.bigint "assignee_id"` do bloco `create_table "custom_kanban_cards"`. Adicionar, em ordem alfabética entre as tabelas `custom_kanban_*`, o bloco:

```ruby
  create_table "custom_kanban_card_assignees", force: :cascade do |t|
    t.bigint "custom_kanban_card_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_kanban_card_id", "user_id"], name: "index_kanban_card_assignees_on_card_and_user", unique: true
    t.index ["custom_kanban_card_id"], name: "index_kanban_card_assignees_on_card"
  end
```

Atualizar a versão no topo do schema (`ActiveRecord::Schema[7.1].define(version: 2026_11_10_120000)`).

- [ ] **Step 3: Commit**

```bash
git add db/migrate/20261110120000_add_card_assignees_to_kanban.rb db/schema.rb
git commit --no-verify -m "feat(kanban): add card assignees join table with backfill"
```

---

## Task 2: Model `CardAssignee` + associações no Card

**Files:**
- Create: `app/models/custom/kanban/card_assignee.rb`
- Modify: `app/models/custom/kanban/card.rb:8` (remove `belongs_to :assignee`), associações + validação
- Test: `spec/models/custom/kanban/card_spec.rb`

**Interfaces:**
- Consumes: `Custom::Kanban::Board#member_users` (relação existente).
- Produces: `Custom::Kanban::Card#assignees` (users, through `card_assignees`), `#assignee_ids=`, validação `assignees_are_board_members`.

- [ ] **Step 1: Escrever o spec (falha)**

```ruby
# spec/models/custom/kanban/card_spec.rb
require 'rails_helper'

RSpec.describe Custom::Kanban::Card do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:member) { create(:user, account: account) }
  let(:outsider) { create(:user, account: account) }
  let(:board) { Custom::Kanban::Board.create!(account: account, name: 'B', created_by: owner) }
  let(:column) { board.columns.create!(name: 'To do', position: 0) }

  before do
    board.members.create!(user: owner)
    board.members.create!(user: member)
  end

  it 'accepts assignees who are board members' do
    card = column.cards.create!(title: 'T', assignee_ids: [member.id])
    expect(card.assignees).to contain_exactly(member)
  end

  it 'rejects an assignee who is not a board member' do
    card = column.cards.new(title: 'T', assignee_ids: [outsider.id])
    expect(card).not_to be_valid
    expect(card.errors[:assignees]).to be_present
  end
end
```

- [ ] **Step 2: Criar o model `CardAssignee`**

```ruby
# app/models/custom/kanban/card_assignee.rb
# [fazer.ai fork] Join between a Kanban card and an assigned user (board member).
class Custom::Kanban::CardAssignee < ApplicationRecord
  self.table_name = 'custom_kanban_card_assignees'

  belongs_to :card, class_name: 'Custom::Kanban::Card', foreign_key: :custom_kanban_card_id, inverse_of: :card_assignees
  belongs_to :user

  validates :user_id, uniqueness: { scope: :custom_kanban_card_id }
end
```

- [ ] **Step 3: Atualizar o Card**

Em `app/models/custom/kanban/card.rb`, remover `belongs_to :assignee, class_name: 'User', optional: true` e adicionar as associações + validação:

```ruby
  has_many :card_assignees, class_name: 'Custom::Kanban::CardAssignee',
                            foreign_key: :custom_kanban_card_id, inverse_of: :card, dependent: :destroy
  has_many :assignees, through: :card_assignees, source: :user
```

E, junto das validações existentes:

```ruby
  validate :assignees_are_board_members
```

No bloco `private`:

```ruby
  def assignees_are_board_members
    member_ids = board.member_users.pluck(:id)
    errors.add(:assignees, 'must be board members') if assignees.any? { |user| member_ids.exclude?(user.id) }
  end
```

- [ ] **Step 4: Commit** (spec roda na CI)

```bash
git add app/models/custom/kanban/card_assignee.rb app/models/custom/kanban/card.rb spec/models/custom/kanban/card_spec.rb
git commit --no-verify -m "feat(kanban): card has many assignees restricted to board members"
```

---

## Task 3: Payload — `assignee_ids` no card e `members` no board

**Files:**
- Modify: `app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder:5`
- Modify: `app/views/api/v1/accounts/custom/kanban/boards/show.json.jbuilder`
- Test: `spec/requests/api/v1/accounts/custom/kanban/cards_spec.rb`

**Interfaces:**
- Produces: cada card com `assignee_ids: number[]`; o board `show` com `members: [{ user_id, name, thumbnail }]`.

- [ ] **Step 1: Card payload → `assignee_ids`**

Em `_card.json.jbuilder`, trocar a linha `json.assignee_id card.assignee_id` por:

```ruby
json.assignee_ids card.assignees.map(&:id)
```

- [ ] **Step 2: Board `show` embarca membros + eager-load**

Em `show.json.jbuilder`, trocar o eager-load do `includes(cards: :labels)` por `includes(cards: %i[labels assignees])` e adicionar, ao final, a lista de membros:

```ruby
json.partial! 'api/v1/accounts/custom/kanban/boards/board', board: @board
json.columns @board.columns.includes(cards: %i[labels assignees]) do |column|
  json.partial! 'api/v1/accounts/custom/kanban/boards/column', column: column
  json.cards column.cards do |card|
    json.partial! 'api/v1/accounts/custom/kanban/boards/card', card: card
  end
end
json.labels @board.labels.order(:name) do |label|
  json.partial! 'api/v1/accounts/custom/kanban/boards/label', label: label
end
json.members @board.members.includes(:user) do |member|
  json.user_id member.user_id
  json.name member.user.name
  json.thumbnail member.user.avatar_url
end
```

- [ ] **Step 3: Request spec (falha → passa na CI)**

```ruby
# spec/requests/api/v1/accounts/custom/kanban/cards_spec.rb  (adicionar exemplo)
it 'returns assignee_ids on the card and members on the board' do
  card.assignees << member
  get "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}",
      headers: owner.create_new_auth_token
  body = response.parsed_body
  expect(body['members'].map { |m| m['user_id'] }).to include(member.id)
  returned = body['columns'].flat_map { |c| c['cards'] }.find { |c| c['id'] == card.id }
  expect(returned['assignee_ids']).to include(member.id)
end
```

- [ ] **Step 4: Commit**

```bash
git add app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder app/views/api/v1/accounts/custom/kanban/boards/show.json.jbuilder spec/requests/api/v1/accounts/custom/kanban/cards_spec.rb
git commit --no-verify -m "feat(kanban): expose assignee_ids and board members in payload"
```

---

## Task 4: CardsController — `assignee_ids` + validação de pertencimento

**Files:**
- Modify: `app/controllers/api/v1/accounts/custom/kanban/cards_controller.rb`
- Test: `spec/requests/api/v1/accounts/custom/kanban/cards_spec.rb`

**Interfaces:**
- Consumes: `@current_board.member_users`.
- Produces: create/update aceitam `card[:assignee_ids]` (array); responsável fora dos membros → `422`.

- [ ] **Step 1: Request spec (falha → CI)**

```ruby
it 'assigns multiple board members to a card' do
  post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
       params: { card: { column_id: column.id, title: 'T', assignee_ids: [owner.id, member.id] } },
       headers: owner.create_new_auth_token
  expect(response).to have_http_status(:success)
  expect(response.parsed_body['assignee_ids']).to contain_exactly(owner.id, member.id)
end

it 'rejects an assignee who is not a board member' do
  post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
       params: { card: { column_id: column.id, title: 'T', assignee_ids: [outsider.id] } },
       headers: owner.create_new_auth_token
  expect(response).to have_http_status(:unprocessable_entity)
end
```

- [ ] **Step 2: Reescrever o controller**

Substituir `validate_assignee!`, `card_params`, e os pontos de create/update:

```ruby
class Api::V1::Accounts::Custom::Kanban::CardsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_card, only: [:update, :destroy, :move]
  before_action :validate_assignees!, only: [:create, :update]

  def create
    column = @current_board.columns.find(params.require(:card).require(:column_id))
    @card = column.cards.create!(card_params.merge(position: column.cards.count, created_by_id: current_user.id))
    assign_labels(@card)
    assign_assignees(@card)
    render :show
  end

  def update
    @card.update!(card_params)
    assign_labels(@card) if params[:card].key?(:label_ids)
    assign_assignees(@card) if params[:card].key?(:assignee_ids)
    render :show
  end

  # destroy / move unchanged

  private

  # set_card unchanged

  def validate_assignees!
    ids = Array(params.dig(:card, :assignee_ids)).map(&:to_i)
    return if ids.all? { |id| @current_board.member_users.exists?(id) }

    render json: { error: 'Assignee must be a member of this board' }, status: :unprocessable_entity
  end

  def assign_labels(card)
    ids = Array(params.dig(:card, :label_ids)).map(&:to_i)
    card.label_ids = @current_board.labels.where(id: ids).pluck(:id)
  end

  def assign_assignees(card)
    ids = Array(params.dig(:card, :assignee_ids)).map(&:to_i)
    card.assignee_ids = @current_board.member_users.where(id: ids).pluck(:id)
  end

  def card_params
    params.require(:card).permit(:title, :description, :due_date)
  end
end
```

(`assignee_id` sai de `card_params`; `assignee_ids` é tratado por `assign_assignees`.)

- [ ] **Step 3: Commit**

```bash
git add app/controllers/api/v1/accounts/custom/kanban/cards_controller.rb spec/requests/api/v1/accounts/custom/kanban/cards_spec.rb
git commit --no-verify -m "feat(kanban): accept assignee_ids and validate board membership"
```

---

## Task 5: Helper de prazo + `KanbanCard.vue` (card estilo Trello)

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/kanban/cardDateFormat.js`
- Create: `app/javascript/dashboard/routes/dashboard/kanban/components/specs/cardDateFormat.spec.js`
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanCard.vue`

**Interfaces:**
- Produces: `formatDueDate(dateString): string` ("14 nov"), `isOverdue(dateString): boolean`.
- Consumes (KanbanCard): props `card`, `labels`, `members` (`[{ user_id, name, thumbnail }]`).

- [ ] **Step 1: Spec do helper (falha)**

```js
// cardDateFormat.spec.js
import { formatDueDate, isOverdue } from '../../cardDateFormat';

describe('cardDateFormat', () => {
  it('formats a date as short day/month', () => {
    expect(formatDueDate('2026-11-14')).toBe('14 nov');
  });
  it('flags past dates as overdue', () => {
    expect(isOverdue('2000-01-01')).toBe(true);
    expect(isOverdue('2999-01-01')).toBe(false);
  });
  it('handles empty input', () => {
    expect(formatDueDate(null)).toBe('');
    expect(isOverdue(null)).toBe(false);
  });
});
```

- [ ] **Step 2: Implementar o helper**

```js
// app/javascript/dashboard/routes/dashboard/kanban/cardDateFormat.js
import { format, parseISO, isPast, isToday } from 'date-fns';

// Short due-date label for a card face, e.g. "14 nov".
export const formatDueDate = dateString => {
  if (!dateString) return '';
  return format(parseISO(dateString), 'd MMM');
};

// A due date is overdue once its day is in the past (today is still on time).
export const isOverdue = dateString => {
  if (!dateString) return false;
  const date = parseISO(dateString);
  return isPast(date) && !isToday(date);
};
```

- [ ] **Step 3: Reescrever `KanbanCard.vue`**

```vue
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
        <Icon v-if="hasDescription" icon="i-lucide-align-left" class="size-3.5" />
        <span v-if="commentCount" class="inline-flex items-center gap-0.5 text-xs">
          <Icon icon="i-lucide-message-square" class="size-3.5" />{{ commentCount }}
        </span>
        <span v-if="attachmentCount" class="inline-flex items-center gap-0.5 text-xs">
          <Icon icon="i-lucide-paperclip" class="size-3.5" />{{ attachmentCount }}
        </span>
      </div>
      <div v-if="cardAssignees.length" class="flex ltr:-space-x-2 rtl:space-x-reverse">
        <Avatar
          v-for="assignee in cardAssignees"
          :key="assignee.user_id"
          :name="assignee.name"
          :src="assignee.thumbnail"
          :size="22"
          rounded-full
          class="ring-2 ring-n-solid-1 rounded-full"
        />
      </div>
    </div>
  </div>
</template>
```

- [ ] **Step 4: Rodar o spec do helper**

Run: `pnpm test app/javascript/dashboard/routes/dashboard/kanban/components/specs/cardDateFormat.spec.js`
Expected: PASS (se o ambiente local não rodar vitest, validar na CI).

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/cardDateFormat.js app/javascript/dashboard/routes/dashboard/kanban/components/specs/cardDateFormat.spec.js app/javascript/dashboard/routes/dashboard/kanban/components/KanbanCard.vue
git commit --no-verify -m "feat(kanban): trello-style card face with assignee avatars and due badge"
```

---

## Task 6: `AssigneePicker.vue` — seletor múltiplo de membros

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/kanban/components/AssigneePicker.vue`

**Interfaces:**
- Consumes: props `members` (`[{ user_id, name, thumbnail }]`), `modelValue` (`number[]`).
- Produces: `update:modelValue` com o novo array de `user_id`.

- [ ] **Step 1: Implementar o componente**

```vue
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
  <ul class="flex flex-col gap-1 max-h-48 overflow-y-auto">
    <li v-for="member in members" :key="member.user_id">
      <button
        type="button"
        class="flex items-center w-full gap-2 px-2 py-1.5 text-sm rounded-lg text-n-slate-12 hover:bg-n-alpha-black2"
        @click="toggle(member.user_id)"
      >
        <Avatar :name="member.name" :src="member.thumbnail" :size="24" rounded-full />
        <span class="flex-1 text-start truncate">{{ member.name }}</span>
        <Icon
          v-if="modelValue.includes(member.user_id)"
          icon="i-lucide-check"
          class="size-4 text-n-brand"
        />
      </button>
    </li>
  </ul>
</template>
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/AssigneePicker.vue
git commit --no-verify -m "feat(kanban): multi-select assignee picker restricted to board members"
```

---

## Task 7: `CardDialog.vue` — modal largo em duas colunas

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue`

**Interfaces:**
- Consumes: props existentes + `members` (do board); `AssigneePicker`, `CardComments`, `CardAttachments`.
- O form passa a carregar `assignee_ids` (array) no lugar de `assignee_id`.

- [ ] **Step 1: Reescrever o `<script setup>`**

Trocar `assignee_id` por `assignee_ids` no `emptyForm`, no `watch` e manter a lógica de save. Adicionar prop `members` e estado de abertura dos popovers:

```js
const props = defineProps({
  boardId: { type: [String, Number], required: true },
  card: { type: Object, default: null },
  columnId: { type: [String, Number], default: null },
  labels: { type: Array, default: () => [] },
  members: { type: Array, default: () => [] },
  isOwner: { type: Boolean, default: false },
});

const emptyForm = () => ({
  title: '',
  description: '',
  assignee_ids: [],
  due_date: null,
  label_ids: [],
});
```

No `watch`, `assignee_ids: [...(card.assignee_ids || [])]`. O `save` continua enviando `...form.value` (já inclui `assignee_ids`).

Adicionar:

```js
const selectedAssignees = computed(() =>
  props.members.filter(m => form.value.assignee_ids.includes(m.user_id))
);
const showAssigneePicker = ref(false);
const showLabelPicker = ref(false);
```

- [ ] **Step 2: Reescrever o `<template>` com `width="4xl"` e duas colunas**

```vue
<template>
  <Dialog
    ref="dialogRef"
    width="4xl"
    :show-confirm-button="false"
    :show-cancel-button="false"
  >
    <div class="flex flex-col gap-1 mb-4">
      <input
        v-model="form.title"
        :placeholder="t('KANBAN.CARD.TITLE')"
        class="text-base font-medium bg-transparent rounded text-n-slate-12 hover:bg-n-alpha-black2 focus:bg-n-alpha-black2 px-1 py-0.5"
      />
      <span v-if="columnName" class="px-1 text-xs text-n-slate-10">
        {{ t('KANBAN.CARD.IN_COLUMN', { column: columnName }) }}
      </span>
    </div>

    <div class="flex flex-col gap-6 md:flex-row">
      <!-- Coluna esquerda: card -->
      <div class="flex flex-col flex-1 gap-4 md:border-e md:border-n-weak md:pe-6">
        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.ASSIGNEES') }}
          </h4>
          <div class="flex flex-wrap items-center gap-2">
            <span
              v-for="assignee in selectedAssignees"
              :key="assignee.user_id"
              class="flex items-center gap-1.5 ps-1 pe-2 py-0.5 rounded-full bg-n-alpha-black2"
            >
              <Avatar :name="assignee.name" :src="assignee.thumbnail" :size="20" rounded-full />
              <span class="text-xs text-n-slate-12">{{ assignee.name }}</span>
            </span>
            <div class="relative">
              <button
                type="button"
                class="flex items-center justify-center rounded-full size-7 border border-dashed border-n-weak text-n-slate-10 hover:text-n-slate-12"
                @click="showAssigneePicker = !showAssigneePicker"
              >
                <Icon icon="i-lucide-plus" class="size-4" />
              </button>
              <div
                v-if="showAssigneePicker"
                v-on-click-outside="() => (showAssigneePicker = false)"
                class="absolute z-10 p-2 mt-1 border rounded-lg shadow-lg bg-n-solid-1 border-n-weak w-56"
              >
                <AssigneePicker v-model="form.assignee_ids" :members="members" />
              </div>
            </div>
          </div>
        </section>

        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.LABELS') }}
          </h4>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="label in labels"
              :key="label.id"
              type="button"
              class="h-6 px-2 text-xs text-white rounded-full"
              :style="{
                backgroundColor: label.color,
                opacity: form.label_ids.includes(label.id) ? 1 : 0.4,
              }"
              @click="toggleLabel(label.id)"
            >
              {{ label.name }}
            </button>
          </div>
        </section>

        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.DUE_DATE') }}
          </h4>
          <input
            v-model="form.due_date"
            type="date"
            class="self-start px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
          />
        </section>

        <section class="flex flex-col gap-2">
          <h4 class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('KANBAN.CARD.DESCRIPTION') }}
          </h4>
          <textarea
            v-model="form.description"
            :placeholder="t('KANBAN.CARD.DESCRIPTION')"
            rows="4"
            class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
          />
        </section>

        <CardAttachments v-if="liveCard" :board-id="boardId" :card="liveCard" />

        <div class="flex items-center justify-between mt-2">
          <button v-if="card" class="text-sm text-n-ruby-11" @click="remove">
            {{ t('KANBAN.CARD.DELETE') }}
          </button>
          <button
            class="px-3 py-1.5 ms-auto text-sm text-white rounded-lg bg-n-brand"
            @click="save"
          >
            {{ t('KANBAN.CARD.SAVE') }}
          </button>
        </div>
      </div>

      <!-- Coluna direita: comentários -->
      <div v-if="liveCard" class="flex flex-col md:w-72 shrink-0">
        <CardComments :board-id="boardId" :card="liveCard" :is-owner="isOwner" />
      </div>
    </div>
  </Dialog>
</template>
```

Imports adicionais no `<script setup>`: `Icon`, `Avatar`, `AssigneePicker`, e `vOnClickOutside` de `@vueuse/components`. Adicionar `columnName` computando o nome da coluna do `liveCard`/`columnId` a partir de `currentBoard`.

```js
import { vOnClickOutside } from '@vueuse/components';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import AssigneePicker from './AssigneePicker.vue';

const columnName = computed(() => {
  const columns = currentBoard.value?.columns ?? [];
  const columnId = props.card
    ? columns.find(c => c.cards.some(card => card.id === props.card.id))?.id
    : props.columnId;
  return columns.find(c => c.id === columnId)?.name ?? '';
});
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue
git commit --no-verify -m "feat(kanban): wide two-column card dialog with assignee picker and side comments"
```

---

## Task 8: `KanbanColumn.vue` — contador + botão ＋ no topo

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanColumn.vue`

**Interfaces:**
- Consumes: já recebe `column`, `visibleCardIds`, `labels`; passa a receber `members` e repassar ao `KanbanCard`.
- Produces: eventos `addCard` (já existe) agora acionados também pelo ＋ do topo.

- [ ] **Step 1: Prop `members` + contador + botão no cabeçalho**

Adicionar `members: { type: Array, default: () => [] }` nos props. No cabeçalho, entre o input e a lixeira:

```vue
    <div class="flex items-center gap-1">
      <input
        v-model="name"
        class="flex-1 min-w-0 px-1 text-sm font-medium bg-transparent rounded text-n-slate-12 hover:bg-n-alpha-black2 focus:bg-n-alpha-black2"
        @keyup.enter="renameColumn"
        @blur="renameColumn"
      />
      <span class="px-1.5 text-xs rounded-full text-n-slate-10 bg-n-alpha-black2">
        {{ column.cards.length }}
      </span>
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

E no `KanbanCard` dentro do draggable, repassar `:members="members"`.

- [ ] **Step 2: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/components/KanbanColumn.vue
git commit --no-verify -m "feat(kanban): column header with card count and top add button"
```

---

## Task 9: `BoardView.vue` — filtros + "Meus cards" + múltiplos responsáveis

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/BoardView.vue`

**Interfaces:**
- Consumes: `kanban/getCurrentBoard` (agora com `members`), `getCurrentUser`.
- Produces: passa `:members="members"` às colunas e ao `CardDialog`.

- [ ] **Step 1: Membros, filtro de múltiplos responsáveis e "Meus cards"**

No `<script setup>`:

```js
const currentUser = useMapGetter('getCurrentUser');
const members = computed(() => board.value?.members ?? []);
const onlyMine = ref(false);

const visibleCardIds = column =>
  column.cards
    .filter(card => {
      const assignees = card.assignee_ids ?? [];
      return (
        (!assigneeFilter.value || assignees.includes(assigneeFilter.value)) &&
        (!labelFilter.value || card.label_ids?.includes(labelFilter.value)) &&
        (!onlyMine.value || assignees.includes(currentUser.value.id))
      );
    })
    .map(card => card.id);

const clearFilters = () => {
  assigneeFilter.value = null;
  labelFilter.value = null;
  onlyMine.value = false;
};
```

Remover o `store.dispatch('agents/get')` e o getter `agents` se não forem mais usados pelo filtro — o filtro de responsável passa a listar `members`. Atualizar o `<option>` do filtro de responsável para iterar `members` (`:value="member.user_id"`, `{{ member.name }}`).

- [ ] **Step 2: Toggle "Meus cards" no header + passar `members`**

No `<template>`, adicionar após os selects:

```vue
      <button
        class="px-2 py-1 text-xs border rounded-lg"
        :class="
          onlyMine
            ? 'border-n-brand text-n-brand'
            : 'border-n-weak text-n-slate-11'
        "
        @click="onlyMine = !onlyMine"
      >
        {{ t('KANBAN.FILTERS.MY_CARDS') }}
      </button>
```

Atualizar a condição do botão "limpar": `v-if="assigneeFilter || labelFilter || onlyMine"`. Passar `:members="members"` em `<KanbanColumn>` e em `<CardDialog>`.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban/BoardView.vue
git commit --no-verify -m "feat(kanban): member-based assignee filter and my-cards toggle"
```

---

## Task 10: i18n (en, pt_BR, es)

**Files:**
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/en/kanban.json`
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/kanban.json`
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/es/kanban.json`

**Interfaces:**
- Produces: chaves `KANBAN.CARD.ASSIGNEES`, `KANBAN.CARD.LABELS`, `KANBAN.CARD.DUE_DATE`, `KANBAN.CARD.IN_COLUMN`, `KANBAN.FILTERS.MY_CARDS`.

- [ ] **Step 1: Adicionar as chaves nos três locais**

`en`:
```json
"CARD": { "ASSIGNEES": "Assignees", "LABELS": "Labels", "DUE_DATE": "Due date", "IN_COLUMN": "in {column}" },
"FILTERS": { "MY_CARDS": "My cards" }
```
`pt_BR`:
```json
"CARD": { "ASSIGNEES": "Responsáveis", "LABELS": "Etiquetas", "DUE_DATE": "Prazo", "IN_COLUMN": "em {column}" },
"FILTERS": { "MY_CARDS": "Meus cards" }
```
`es`:
```json
"CARD": { "ASSIGNEES": "Responsables", "LABELS": "Etiquetas", "DUE_DATE": "Fecha límite", "IN_COLUMN": "en {column}" },
"FILTERS": { "MY_CARDS": "Mis tarjetas" }
```

Mesclar com as chaves `CARD`/`FILTERS` já existentes (não sobrescrever `TITLE`, `DESCRIPTION`, `ASSIGNEE`, `SAVE`, `DELETE`, `ASSIGNEE`/`LABEL`/`CLEAR`). Remover a chave `CARD.ASSIGNEE` (singular) se não for mais referenciada.

- [ ] **Step 2: Checar cobertura i18n**

Run: `ruby scripts/i18n/fork_translations.rb check`
Expected: PASS (sem Ruby local, valida na CI via `fazer_ai_i18n.yml`).

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/i18n/fazer-ai/locale/en/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/es/kanban.json
git commit --no-verify -m "feat(kanban): i18n for assignees, labels, due date and my-cards filter"
```

---

## Task 11: lint + registro da mudança

**Files:**
- Modify: `.claude/CLAUDE.md` (seção "Mudanças nossas" / status do Kanban)

- [ ] **Step 1: Lint do frontend**

Run: `pnpm eslint:fix app/javascript/dashboard/routes/dashboard/kanban`
Expected: sem erros (atenção ao gotcha de CRLF no Windows — se acusar `prettier/prettier` de fim de linha, não é bloqueante local; a CI roda em LF).

- [ ] **Step 2: Registrar no `.claude/CLAUDE.md`**

No bloco do Kanban em "Mudanças nossas", anexar uma Fase 3: múltiplos responsáveis (tabela `custom_kanban_card_assignees`), card estilo Trello (pills + avatares + badge de prazo), modal largo 2 colunas, coluna com contador + ＋, filtro "Meus cards". Listar os arquivos novos e o schema editado. Apontar a spec/plano em `docs/superpowers/`.

- [ ] **Step 3: Commit**

```bash
git add .claude/CLAUDE.md
git commit --no-verify -m "docs(kanban): record phase 3 (multi-assignee + visual refresh) in fork notes"
```

---

## Self-Review

- **Spec coverage:** múltiplos responsáveis (T1–T4), regra membro-do-quadro (T2/T4), card pills+avatares+prazo+ícones (T5), modal largo 2 colunas + comentários lateral + inline (T7), seletor múltiplo (T6), coluna contador+＋ (T8), filtros restilizados + "Meus cards" + filtro multi (T9), i18n 3 locais (T10), payload members+assignee_ids (T3). Tudo coberto.
- **Placeholders:** nenhum — código completo em cada passo.
- **Type consistency:** `assignee_ids` (array de `user_id`) consistente entre payload (T3), controller (T4), card face (T5), picker (T6 `modelValue`), dialog (T7) e filtro (T9). `members` = `[{ user_id, name, thumbnail }]` consistente de T3 a T9. `formatDueDate`/`isOverdue` definidos em T5 e usados só lá.
- **Edição upstream:** só `db/schema.rb` (já editado pela feature). Resto em arquivos nossos.
