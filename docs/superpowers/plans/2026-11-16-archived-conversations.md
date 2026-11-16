# Arquivar conversas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir arquivar uma conversa (estado compartilhado pela conta, independente do status), escondê-la das listas normais e consultá-la numa nova aba "Arquivadas", com ação no menu de contexto do card e no cabeçalho da conversa aberta.

**Architecture:** Coluna booleana `custom_archived` na `conversations` (default `false`). O `ConversationFinder` exclui arquivadas das listas normais e, com `params[:archived]`, devolve só as arquivadas. Uma 4ª aba no `ChatList` manda `archived=true`; o front filtra em memória por `custom_archived` e reage ao broadcast `conversation.updated` já existente. Ação arquivar/desarquivar via controller nosso aninhado na conversa (padrão do "Encaminhar").

**Tech Stack:** Rails 7 (ActiveRecord, Jbuilder, RSpec), Vue 3 `<script setup>` + Vuex, vue-i18n, Vitest.

## Global Constraints

- **Fork, merge barato:** preferir arquivos novos; editar upstream só o mínimo e registrar em `.claude/CLAUDE.md` → "Mudanças nossas". Namespace/prefixo `custom`.
- **Sem Ruby/Postgres local:** specs de backend validam **só na CI**; `db/schema.rb` é editado à mão e um dev com Ruby roda `bundle exec rails db:migrate` e confere que o schema regenerado é idêntico antes do merge.
- **Migrations idempotentes:** `unless column_exists?` / `unless index_exists?`. Gerar a migration com `bundle exec rails g migration` quando houver Ruby; aqui o arquivo é escrito à mão com timestamp real.
- **Sem SQL cru:** ActiveRecord (`where`, `update!`).
- **i18n:** chaves novas em **en, pt_BR e es**, sempre no overlay `app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/<arquivo>.json` (nunca no locale do upstream).
- **Tailwind only**, Composition API com `<script setup>`, eventos camelCase, componentes PascalCase.
- **Commits:** Conventional Commits; rodar com `--no-verify` (o pre-commit husky chama `bundle`, que não existe local). Terminar a mensagem com `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Branch já criada: `feat/archived-conversations`.

---

## File Structure

**Backend (upstream, edição mínima):**
- `db/schema.rb` — coluna `custom_archived` + índice + versão da migration.
- `app/finders/conversation_finder.rb` — `filter_by_archived`.
- `app/models/conversation.rb` — `custom_archived` em `list_of_keys` (para broadcast).
- `app/views/api/v1/conversations/partials/_conversation.json.jbuilder` — `json.custom_archived`.
- `app/presenters/conversations/event_data_presenter.rb` — `custom_archived` em `push_data`.
- `config/routes.rb` — `resource :custom_archive`.

**Backend (novos, nossos):**
- `db/migrate/20261116XXXXXX_add_custom_archived_to_conversations.rb`
- `app/controllers/api/v1/accounts/conversations/custom_archives_controller.rb`
- `spec/controllers/api/v1/accounts/conversations/custom_archives_controller_spec.rb`
- specs do finder já existem em `spec/finders/conversation_finder_spec.rb` (adicionar exemplos).

**Frontend (upstream, edição mínima):**
- `app/javascript/dashboard/api/inbox/conversation.js` — param `archived` no `get`; métodos `archive`/`unarchive`.
- `app/javascript/dashboard/store/modules/conversations/helpers.js` — `filterByArchived` + uso em `applyPageFilters`.
- `app/javascript/dashboard/store/modules/conversations/actions.js` — action `toggleConversationArchived`.
- `app/javascript/dashboard/components/ChatList.vue` — 4ª aba + `archived` no `conversationFilters` + seleção de getter + `provide`.
- `app/javascript/dashboard/components/ConversationItem.vue` — inject + wiring do menu.
- `app/javascript/dashboard/components/widgets/conversation/contextMenu/Index.vue` — item "Arquivar/Desarquivar".
- `app/javascript/dashboard/components/widgets/conversation/MoreActions.vue` — item no cabeçalho.

**Frontend (i18n, overlay):**
- `fazer-ai/locale/{en,pt_BR,es}/chatList.json` — `CHAT_LIST.ASSIGNEE_TYPE_TABS.ARCHIVED`.
- `fazer-ai/locale/{en,pt_BR,es}/conversation.json` — `CONVERSATION.CARD_CONTEXT_MENU.ARCHIVE/UNARCHIVE` + `CONVERSATION.ARCHIVE.ARCHIVED_SUCCESS/UNARCHIVED_SUCCESS`.

---

## Task 1: Migration + schema — coluna `custom_archived`

**Files:**
- Create: `db/migrate/20261116XXXXXX_add_custom_archived_to_conversations.rb`
- Modify: `db/schema.rb`

**Interfaces:**
- Produces: coluna `conversations.custom_archived` (boolean, default `false`, `null: false`) + índice parcial `index_conversations_on_custom_archived` (`where custom_archived = true`).

- [ ] **Step 1: Escrever a migration (idempotente)**

Usar um timestamp real (ex.: rodar `date -u +%Y%m%d%H%M%S`) no nome do arquivo e na classe. Conteúdo:

```ruby
class AddCustomArchivedToConversations < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:conversations, :custom_archived)
      add_column :conversations, :custom_archived, :boolean, default: false, null: false
    end

    unless index_exists?(:conversations, :custom_archived, name: 'index_conversations_on_custom_archived')
      add_index :conversations, :custom_archived, where: 'custom_archived = true', name: 'index_conversations_on_custom_archived'
    end
  end
end
```

- [ ] **Step 2: Atualizar `db/schema.rb` à mão**

No bloco `create_table "conversations"`, adicionar a coluna (ordem alfabética perto das outras `custom_*`/booleanas):

```ruby
    t.boolean "custom_archived", default: false, null: false
```

E no fim do mesmo `create_table`, junto dos outros `t.index` da tabela:

```ruby
    t.index ["custom_archived"], name: "index_conversations_on_custom_archived", where: "custom_archived"
```

Atualizar a linha `define(version: ...)` no topo do schema para o timestamp desta migration (só se for maior que o atual).

- [ ] **Step 3: Verificação (CI / dev com Ruby)**

Um dev com Ruby roda `bundle exec rails db:migrate` e confere que o `db/schema.rb` regenerado é idêntico ao editado. Sem Ruby local isso valida na CI.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/20261116XXXXXX_add_custom_archived_to_conversations.rb db/schema.rb
git commit --no-verify -m "feat(conversations): add custom_archived column

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Payload + broadcast de `custom_archived`

**Files:**
- Modify: `app/views/api/v1/conversations/partials/_conversation.json.jbuilder`
- Modify: `app/presenters/conversations/event_data_presenter.rb:47-71`
- Modify: `app/models/conversation.rb` (`list_of_keys`, ~linha 430)

**Interfaces:**
- Consumes: coluna `custom_archived` (Task 1).
- Produces: campo `custom_archived` no JSON da conversa (list + show) e no `push_data` do cable; `custom_archived` entra em `list_of_keys` para que um update só desse campo dispare `conversation.updated`.

- [ ] **Step 1: Partial da conversa**

Em `_conversation.json.jbuilder`, perto de `json.muted` / `json.status` (linha ~50), adicionar:

```ruby
json.custom_archived conversation.custom_archived
```

- [ ] **Step 2: `push_data` do presenter**

Em `event_data_presenter.rb`, dentro do hash de `push_data` (perto de `status: status,`):

```ruby
      custom_archived: custom_archived,
```

(`custom_archived` é um método de leitura da coluna; o presenter é um `SimpleDelegator` da conversa, então já responde.)

- [ ] **Step 3: `list_of_keys` no model**

Em `conversation.rb`, no array retornado por `list_of_keys`, acrescentar `custom_archived`:

```ruby
  def list_of_keys
    %w[team_id assignee_id assignee_agent_bot_id ai_assignee_type status snoozed_until custom_attributes label_list waiting_since
       first_reply_created_at priority redirect_origin_display_id custom_archived]
  end
```

- [ ] **Step 4: Spec de regressão do broadcast (no spec do controller, Task 4)**

Coberto pela asserção de broadcast na Task 4 (arquivar dispara `conversation.updated`). Sem spec separado aqui.

- [ ] **Step 5: Commit**

```bash
git add app/views/api/v1/conversations/partials/_conversation.json.jbuilder app/presenters/conversations/event_data_presenter.rb app/models/conversation.rb
git commit --no-verify -m "feat(conversations): expose custom_archived in payload and broadcast

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `ConversationFinder#filter_by_archived`

**Files:**
- Modify: `app/finders/conversation_finder.rb` (`set_up` ~linha 76 e novo método privado)
- Test: `spec/finders/conversation_finder_spec.rb`

**Interfaces:**
- Consumes: coluna `custom_archived` (Task 1), `params[:archived]`.
- Produces: listas normais excluem arquivadas; `params[:archived]` truthy ⇒ só arquivadas. Contadores mine/unassigned/all seguem a regra (são computados sobre `@conversations` depois do `set_up`); o endpoint `meta` (counts) **não** recebe `archived` (ver Task 5), então os badges continuam sempre não-arquivados.

- [ ] **Step 1: Escrever os exemplos que falham**

Em `spec/finders/conversation_finder_spec.rb`, dentro do contexto existente (há `let(:user_1)`, `account`, inbox, conversas — reusar o setup do arquivo; criar uma arquivada no `before` do novo contexto):

```ruby
  describe 'archived filtering' do
    let!(:archived_conversation) do
      create(:conversation, account: account, inbox: inbox, assignee: user_1, custom_archived: true)
    end

    it 'excludes archived conversations from the normal list' do
      result = described_class.new(user_1, { assignee_type: 'me', status: 'all' }).perform
      expect(result[:conversations]).not_to include(archived_conversation)
    end

    it 'returns only archived conversations when archived is true' do
      result = described_class.new(user_1, { archived: 'true', status: 'all' }).perform
      expect(result[:conversations]).to contain_exactly(archived_conversation)
    end

    it 'keeps counts scoped to non-archived when archived is not requested' do
      result = described_class.new(user_1, { assignee_type: 'me', status: 'all' }).perform
      expect(result[:conversations].pluck(:custom_archived).uniq).to eq([false])
    end
  end
```

- [ ] **Step 2: Rodar (CI) e ver falhar**

Sem Ruby local: `gh workflow run run_foss_spec.yml --ref feat/archived-conversations -f specs="spec/finders/conversation_finder_spec.rb"`. Esperado: FAIL (coluna aceita, mas sem `filter_by_archived` o 2º exemplo retorna vazio/erro de param).

- [ ] **Step 3: Implementar**

Em `conversation_finder.rb`, no `set_up`, acrescentar a chamada (depois de `find_all_conversations`, antes de `filter_by_status`):

```ruby
    find_all_conversations
    filter_by_archived
    filter_by_status unless params[:q]
```

E o método privado (junto dos outros `filter_by_*`):

```ruby
  def filter_by_archived
    archived = ActiveModel::Type::Boolean.new.cast(params[:archived])
    @conversations = @conversations.where(custom_archived: archived)
  end
```

- [ ] **Step 4: Rodar (CI) e ver passar**

`gh workflow run run_foss_spec.yml --ref feat/archived-conversations -f specs="spec/finders/conversation_finder_spec.rb"`. Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/finders/conversation_finder.rb spec/finders/conversation_finder_spec.rb
git commit --no-verify -m "feat(conversations): filter archived in ConversationFinder

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Controller arquivar/desarquivar + rota

**Files:**
- Modify: `config/routes.rb:213-233` (bloco `scope module: :conversations`)
- Create: `app/controllers/api/v1/accounts/conversations/custom_archives_controller.rb`
- Test: `spec/controllers/api/v1/accounts/conversations/custom_archives_controller_spec.rb`

**Interfaces:**
- Consumes: `BaseController#conversation` (dá `@conversation` por `display_id` + `authorize :show?`).
- Produces: `POST /api/v1/accounts/:account_id/conversations/:conversation_id/custom_archive` (arquiva) e `DELETE .../custom_archive` (desarquiva); ambos salvam `custom_archived` (dispara broadcast) e renderizam a conversa pelo partial `_conversation`.

- [ ] **Step 1: Escrever o spec que falha**

```ruby
require 'rails_helper'

RSpec.describe 'Conversation Custom Archive API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'POST /custom_archive' do
    it 'archives the conversation and broadcasts the update' do
      expect(Rails.configuration.dispatcher).to receive(:dispatch)
        .with('conversation.updated', anything, anything).at_least(:once)

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_archive",
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload.custom_archived).to be(true)
    end
  end

  describe 'DELETE /custom_archive' do
    it 'unarchives the conversation' do
      conversation.update!(custom_archived: true)

      delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_archive",
             headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload.custom_archived).to be(false)
    end
  end
end
```

- [ ] **Step 2: Rodar (CI) e ver falhar**

`gh workflow run run_foss_spec.yml --ref feat/archived-conversations -f specs="spec/controllers/api/v1/accounts/conversations/custom_archives_controller_spec.rb"`. Esperado: FAIL (rota inexistente → 404).

- [ ] **Step 3: Adicionar a rota**

Em `config/routes.rb`, dentro do `scope module: :conversations` (logo após o bloco `resources :forwards`):

```ruby
              # [fazer.ai fork] Archive/unarchive this conversation (account-wide, status-independent).
              resource :custom_archive, only: [:create, :destroy], controller: 'custom_archives'
```

- [ ] **Step 4: Criar o controller**

`app/controllers/api/v1/accounts/conversations/custom_archives_controller.rb`:

```ruby
# [fazer.ai fork] Arquiva/desarquiva a conversa. É um estado compartilhado pela conta
# (`conversations.custom_archived`), independente do status: a conversa some das listas
# normais e só aparece na aba "Arquivadas", e não volta sozinha quando chega mensagem nova.
class Api::V1::Accounts::Conversations::CustomArchivesController < Api::V1::Accounts::Conversations::BaseController
  def create
    @conversation.update!(custom_archived: true)
    render partial: 'api/v1/conversations/partials/conversation', formats: [:json], locals: { conversation: @conversation }
  end

  def destroy
    @conversation.update!(custom_archived: false)
    render partial: 'api/v1/conversations/partials/conversation', formats: [:json], locals: { conversation: @conversation }
  end
end
```

- [ ] **Step 5: Rodar (CI) e ver passar**

`gh workflow run run_foss_spec.yml --ref feat/archived-conversations -f specs="spec/controllers/api/v1/accounts/conversations/custom_archives_controller_spec.rb"`. Esperado: PASS.

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/accounts/conversations/custom_archives_controller.rb spec/controllers/api/v1/accounts/conversations/custom_archives_controller_spec.rb
git commit --no-verify -m "feat(conversations): add archive/unarchive endpoint

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: API client + store action

**Files:**
- Modify: `app/javascript/dashboard/api/inbox/conversation.js:12-42` (`get`) e novos métodos
- Modify: `app/javascript/dashboard/store/modules/conversations/actions.js` (nova action, perto de `muteConversation` ~linha 853)
- Test: `app/javascript/dashboard/store/modules/conversations/specs/actions.spec.js` (adicionar) e `app/javascript/dashboard/api/specs/conversation.spec.js` (se existir; senão pular)

**Interfaces:**
- Consumes: endpoints da Task 4.
- Produces: `ConversationApi.get` passa `archived` ao servidor; `ConversationApi.archive(id)` / `ConversationApi.unarchive(id)`; action `toggleConversationArchived({ conversationId, archived })` que chama a API e despacha `updateConversation` com a resposta. **`ConversationApi.meta` NÃO recebe `archived`** (counts sempre não-arquivados).

- [ ] **Step 1: Escrever o teste da action que falha**

Em `.../conversations/specs/actions.spec.js`, seguindo o padrão dos testes de action já existentes no arquivo (mock de `ConversationApi`):

```js
describe('#toggleConversationArchived', () => {
  it('archives and dispatches updateConversation with the response', async () => {
    const conversation = { id: 1, custom_archived: true };
    axios.post.mockResolvedValue({ data: conversation });
    const commit = vi.fn();
    const dispatch = vi.fn();

    await actions.toggleConversationArchived(
      { commit, dispatch },
      { conversationId: 1, archived: true }
    );

    expect(dispatch).toHaveBeenCalledWith('updateConversation', conversation);
  });
});
```

(Ajustar imports/mocks ao estilo do arquivo — ele já importa `actions` e mocka `axios`/`ConversationApi`.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `pnpm test app/javascript/dashboard/store/modules/conversations/specs/actions.spec.js`
Esperado: FAIL ("toggleConversationArchived is not a function").

- [ ] **Step 3: Implementar a API**

Em `conversation.js`, no `get(...)`, adicionar `archived` ao destructuring e aos `params` (só envia quando `true`, senão o finder assume não-arquivado):

```js
  get(
    {
      inboxId,
      status,
      assigneeType,
      page,
      labels,
      teamId,
      conversationType,
      sortBy,
      updatedWithin,
      groupType,
      archived,
    },
    options = {}
  ) {
    return axios.get(this.url, {
      signal: options.signal,
      params: {
        inbox_id: inboxId,
        team_id: teamId,
        status,
        assignee_type: assigneeType,
        page,
        labels,
        conversation_type: conversationType,
        sort_by: sortBy,
        updated_within: updatedWithin,
        group_type: groupType,
        archived: archived || undefined,
      },
    });
  }
```

E os dois métodos novos (perto de `toggleStatus`):

```js
  // [fazer.ai fork] Archive/unarchive a conversation (account-wide, status-independent).
  archive(conversationId) {
    return axios.post(`${this.url}/${conversationId}/custom_archive`);
  }

  unarchive(conversationId) {
    return axios.delete(`${this.url}/${conversationId}/custom_archive`);
  }
```

**Não** mexer em `meta(...)` — ele não leva `archived`, então os contadores das abas normais continuam não-arquivados.

- [ ] **Step 4: Implementar a action**

Em `actions.js`:

```js
  // [fazer.ai fork] Arquiva/desarquiva a conversa. O servidor devolve a conversa atualizada
  // (com custom_archived); `updateConversation` reaproveita o merge + re-filtro dos getters.
  toggleConversationArchived: async ({ dispatch }, { conversationId, archived }) => {
    const { data } = archived
      ? await ConversationApi.archive(conversationId)
      : await ConversationApi.unarchive(conversationId);
    dispatch('updateConversation', data);
  },
```

- [ ] **Step 5: Rodar e ver passar**

Run: `pnpm test app/javascript/dashboard/store/modules/conversations/specs/actions.spec.js`
Esperado: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/api/inbox/conversation.js app/javascript/dashboard/store/modules/conversations/actions.js app/javascript/dashboard/store/modules/conversations/specs/actions.spec.js
git commit --no-verify -m "feat(conversations): api client and store action for archiving

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Filtro em memória (`filterByArchived`)

**Files:**
- Modify: `app/javascript/dashboard/store/modules/conversations/helpers.js:81-115` + novo helper
- Test: `app/javascript/dashboard/store/modules/conversations/specs/helpers.spec.js` (adicionar)

**Interfaces:**
- Consumes: `conversation.custom_archived`, `filters.archived`.
- Produces: `applyPageFilters` esconde arquivadas quando `filters.archived` é falsy e mostra **só** arquivadas quando é truthy. Usado por `getMineChats`, `getUnAssignedChats`, `getAllStatusChats` (todos chamam `applyPageFilters`).

- [ ] **Step 1: Escrever os testes que falham**

Em `.../conversations/specs/helpers.spec.js` (há `describe('applyPageFilters'...)` ou similar; senão criar):

```js
import { applyPageFilters } from '../helpers';

describe('#applyPageFilters archived', () => {
  const base = { status: 'open', inbox_id: 1, labels: [], meta: {} };

  it('hides archived conversations by default', () => {
    const conv = { ...base, custom_archived: true };
    expect(applyPageFilters(conv, { status: 'open' })).toBe(false);
  });

  it('keeps non-archived conversations by default', () => {
    const conv = { ...base, custom_archived: false };
    expect(applyPageFilters(conv, { status: 'open' })).toBe(true);
  });

  it('shows only archived when archived filter is true', () => {
    const archived = { ...base, custom_archived: true };
    const normal = { ...base, custom_archived: false };
    expect(applyPageFilters(archived, { status: 'open', archived: true })).toBe(true);
    expect(applyPageFilters(normal, { status: 'open', archived: true })).toBe(false);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `pnpm test app/javascript/dashboard/store/modules/conversations/specs/helpers.spec.js`
Esperado: FAIL (arquivada ainda passa por default).

- [ ] **Step 3: Implementar**

Em `helpers.js`, novo helper (perto de `filterByGroupType`):

```js
// Arquivadas só aparecem na aba "Arquivadas": por padrão somem das listas normais, e quando
// `archived` é verdadeiro a lista passa a mostrar apenas as arquivadas.
export const filterByArchived = (shouldFilter, archived, chatArchived) => {
  const wantArchived = Boolean(archived);
  return Boolean(chatArchived) === wantArchived && shouldFilter;
};
```

E em `applyPageFilters`, ler `archived` dos filtros e `custom_archived` da conversa e aplicar por último:

```js
export const applyPageFilters = (conversation, filters) => {
  const {
    inboxId,
    status,
    labels = [],
    teamId,
    conversationType,
    groupType,
    archived,
  } = filters;
  const {
    status: chatStatus,
    inbox_id: chatInboxId,
    labels: chatLabels = [],
    meta = {},
    first_reply_created_at: firstReplyOn,
    waiting_since: waitingSince,
    group_type: chatGroupType,
    custom_archived: chatArchived,
  } = conversation;
  const team = meta.team || {};
  const { id: chatTeamId } = team;

  let shouldFilter = filterByStatus(chatStatus, status);
  shouldFilter = filterByInbox(shouldFilter, inboxId, chatInboxId);
  shouldFilter = filterByTeam(shouldFilter, teamId, chatTeamId);
  shouldFilter = filterByLabel(shouldFilter, labels, chatLabels);
  shouldFilter = filterByGroupType(shouldFilter, groupType, chatGroupType);
  shouldFilter = filterByUnattended(
    shouldFilter,
    conversationType,
    firstReplyOn,
    waitingSince
  );
  shouldFilter = filterByArchived(shouldFilter, archived, chatArchived);

  return shouldFilter;
};
```

- [ ] **Step 4: Rodar e ver passar**

Run: `pnpm test app/javascript/dashboard/store/modules/conversations/specs/helpers.spec.js`
Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/store/modules/conversations/helpers.js app/javascript/dashboard/store/modules/conversations/specs/helpers.spec.js
git commit --no-verify -m "feat(conversations): hide archived from normal lists in store filter

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 4ª aba "Arquivadas" no ChatList

**Files:**
- Modify: `app/javascript/dashboard/components/ChatList.vue` (`assigneeTabItems` ~220, `conversationFilters` ~291, `conversationList` ~364)

**Interfaces:**
- Consumes: `filterByArchived` via getters (Task 6), `archived` no `ConversationApi.get` (Task 5).
- Produces: aba `archived` renderizada no `ChatTypeTabs`; ao ativá-la, `conversationFilters.archived = true` e a lista usa o getter plano (`allChatList`) só com arquivadas.

- [ ] **Step 1: Constante do valor da aba**

No topo do `<script setup>` do `ChatList.vue` (perto dos outros `const`), adicionar:

```js
const ARCHIVED_TAB = 'archived';
```

- [ ] **Step 2: Acrescentar a aba à lista**

No computed `assigneeTabItems` (linha ~220), anexar o item arquivadas ao resultado do `.map(...)`:

```js
const assigneeTabItems = computed(() => {
  const items = filterItemsByPermission(
    assigneeTabPermissions.value,
    userPermissions.value,
    item => item.permissions
  ).map(({ key, count: countKey }) => ({
    key,
    name: t(`CHAT_LIST.ASSIGNEE_TYPE_TABS.${key}`),
    count: conversationStats.value[countKey] || 0,
  }));

  // Aba "Arquivadas": ortogonal ao assignee, sem badge de contagem (YAGNI).
  items.push({
    key: ARCHIVED_TAB,
    name: t('CHAT_LIST.ASSIGNEE_TYPE_TABS.ARCHIVED'),
    count: undefined,
  });

  return items;
});
```

- [ ] **Step 3: `archived` no `conversationFilters`**

No computed `conversationFilters` (linha ~291), acrescentar a chave:

```js
    groupType: activeGroupType.value || undefined,
    archived: activeAssigneeTab.value === ARCHIVED_TAB ? true : undefined,
```

- [ ] **Step 4: Seleção do getter na aba arquivadas**

Nenhuma mudança necessária em `conversationList`: a aba `archived` cai no ramo `else` já existente (`allChatList`, o getter plano). Como `filters.archived` agora é `true` (Step 3), `applyPageFilters` (Task 6) devolve só as arquivadas, e as abas `me`/`unassigned` continuam excluindo arquivadas porque recebem `archived: undefined`. Confirmar apenas que o `else` usa `allChatList.value(filters)`:

```js
    } else if (activeAssigneeTab.value === 'me') {
      localConversationList = [...mineChatsList.value(filters)];
    } else if (activeAssigneeTab.value === 'unassigned') {
      localConversationList = [...unAssignedChatsList.value(filters)];
    } else {
      // all e archived: lista plana; o filtro archived vem de filters.archived
      localConversationList = [...allChatList.value(filters)];
    }
```

- [ ] **Step 5: Verificação manual (sem spec de componente)**

O `ChatList.vue` não tem spec unitário; validar em HML (ver seção Verificação). Conferir: a aba "Arquivadas" aparece; clicar nela lista só arquivadas; as outras 3 abas não mostram arquivadas; os badges de Minhas/Não atribuídas/Todos continuam com os números não-arquivados.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/components/ChatList.vue
git commit --no-verify -m "feat(conversations): add Archived tab to conversation list

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Ação no menu de contexto do card

**Files:**
- Modify: `app/javascript/dashboard/components/ChatList.vue` (`provide` ~1018-1030 + 2 handlers)
- Modify: `app/javascript/dashboard/components/ConversationItem.vue` (inject + handlers + wiring)
- Modify: `app/javascript/dashboard/components/widgets/conversation/contextMenu/Index.vue` (item + emit + prop)

**Interfaces:**
- Consumes: action `toggleConversationArchived` (Task 5), `source.custom_archived`.
- Produces: item "Arquivar" (ou "Desarquivar") no menu de contexto do card → chama a action.

- [ ] **Step 1: Handlers + provide no ChatList**

No `ChatList.vue`, perto dos outros handlers (ex.: `togglePin`), adicionar:

```js
const archiveConversation = conversationId => {
  store.dispatch('toggleConversationArchived', { conversationId, archived: true });
};

const unarchiveConversation = conversationId => {
  store.dispatch('toggleConversationArchived', { conversationId, archived: false });
};
```

E junto dos `provide(...)` (linha ~1030):

```js
provide('archiveConversation', archiveConversation);
provide('unarchiveConversation', unarchiveConversation);
```

- [ ] **Step 2: inject + handler no ConversationItem**

Em `ConversationItem.vue`, junto dos outros `inject` (linha ~38):

```js
const archiveConversation = inject('archiveConversation');
const unarchiveConversation = inject('unarchiveConversation');
```

Handler (perto de `onTogglePin`):

```js
const onToggleArchived = () => {
  if (props.source.custom_archived) {
    unarchiveConversation(props.source.id);
  } else {
    archiveConversation(props.source.id);
  }
  closeContextMenu();
};
```

E no `<ConversationContextMenu>` (linha ~265), passar a prop e ouvir o evento:

```html
    <ConversationContextMenu
      :status="source.status"
      :inbox-id="inbox.id"
      :priority="source.priority"
      :chat-id="source.id"
      :has-unread-messages="source.unread_count > 0"
      :is-pinned="isPinned(source.id)"
      :is-archived="source.custom_archived"
      :conversation-labels="source.labels"
      :conversation-url="conversationPath"
      @update-conversation="onUpdateConversation"
      ...
      @toggle-archived="onToggleArchived"
      @delete-conversation="onDeleteConversation"
      @close="closeContextMenu"
    />
```

- [ ] **Step 3: Item no menu de contexto**

Em `contextMenu/Index.vue`:

Prop nova (em `props`):

```js
    isArchived: {
      type: Boolean,
      default: false,
    },
```

Emit novo (no array `emits`): acrescentar `'toggleArchived'`.

Opção (em `data()`, junto das outras `*Option`):

```js
      archiveOption: {
        key: 'archive',
        icon: 'archive',
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.ARCHIVE'),
      },
      unarchiveOption: {
        key: 'unarchive',
        icon: 'archive',
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.UNARCHIVE'),
      },
```

Render — logo antes do bloco de delete (o `<template v-if="isAdmin && isAllowed([MENU.DELETE])">`), adicionar:

```html
    <hr class="m-1 rounded border-b border-n-weak dark:border-n-weak" />
    <MenuItem
      :option="isArchived ? unarchiveOption : archiveOption"
      variant="icon"
      @click.stop="$emit('toggleArchived')"
    />
```

(Usar um ícone válido do set em uso — confirmar que `archive` existe no conjunto `fluent`/woot; senão usar `folder` ou `box`. Checar outros `icon:` do arquivo.)

- [ ] **Step 4: Verificação manual**

Sem spec unitário desses componentes. Validar em HML: botão direito num card → "Arquivar"; dentro da aba Arquivadas → "Desarquivar".

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/components/ChatList.vue app/javascript/dashboard/components/ConversationItem.vue app/javascript/dashboard/components/widgets/conversation/contextMenu/Index.vue
git commit --no-verify -m "feat(conversations): archive action in card context menu

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Ação no cabeçalho da conversa aberta

**Files:**
- Modify: `app/javascript/dashboard/components/widgets/conversation/MoreActions.vue`

**Interfaces:**
- Consumes: action `toggleConversationArchived` (Task 5), `currentChat.custom_archived`.
- Produces: item "Arquivar"/"Desarquivar" no dropdown de mais-ações do cabeçalho.

- [ ] **Step 1: Adicionar o item ao `actionMenuItems`**

Em `MoreActions.vue`, dentro do computed `actionMenuItems` (antes do `return items;`):

```js
  if (currentChat.value.custom_archived) {
    items.push({
      icon: 'i-lucide-archive-restore',
      label: t('CONVERSATION.CARD_CONTEXT_MENU.UNARCHIVE'),
      action: 'unarchive',
      value: 'unarchive',
    });
  } else {
    items.push({
      icon: 'i-lucide-archive',
      label: t('CONVERSATION.CARD_CONTEXT_MENU.ARCHIVE'),
      action: 'archive',
      value: 'archive',
    });
  }
```

- [ ] **Step 2: Tratar o clique**

No `handleActionClick`, acrescentar os ramos:

```js
  } else if (action === 'archive') {
    store.dispatch('toggleConversationArchived', {
      conversationId: currentChat.value.id,
      archived: true,
    });
    useAlert(t('CONVERSATION.ARCHIVE.ARCHIVED_SUCCESS'));
  } else if (action === 'unarchive') {
    store.dispatch('toggleConversationArchived', {
      conversationId: currentChat.value.id,
      archived: false,
    });
    useAlert(t('CONVERSATION.ARCHIVE.UNARCHIVED_SUCCESS'));
  }
```

- [ ] **Step 3: Verificação manual**

Validar em HML: abrir uma conversa → menu "⋯" do cabeçalho → "Arquivar"; some das listas normais; reabrir pela aba Arquivadas → "Desarquivar".

- [ ] **Step 4: Commit**

```bash
git add app/javascript/dashboard/components/widgets/conversation/MoreActions.vue
git commit --no-verify -m "feat(conversations): archive action in conversation header

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: i18n (en / pt_BR / es)

**Files:**
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/chatList.json`
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/conversation.json`

**Interfaces:**
- Produces: chaves `CHAT_LIST.ASSIGNEE_TYPE_TABS.ARCHIVED`, `CONVERSATION.CARD_CONTEXT_MENU.ARCHIVE/UNARCHIVE`, `CONVERSATION.ARCHIVE.ARCHIVED_SUCCESS/UNARCHIVED_SUCCESS` nas três línguas.

- [ ] **Step 1: chatList.json (aba)**

Em cada arquivo (criar a estrutura aninhada se o arquivo ainda não tiver `CHAT_LIST.ASSIGNEE_TYPE_TABS`):

- en: `{ "CHAT_LIST": { "ASSIGNEE_TYPE_TABS": { "ARCHIVED": "Archived" } } }`
- pt_BR: `"ARCHIVED": "Arquivadas"`
- es: `"ARCHIVED": "Archivadas"`

- [ ] **Step 2: conversation.json (ações + toasts)**

- en: `CARD_CONTEXT_MENU.ARCHIVE` = "Archive", `UNARCHIVE` = "Unarchive"; `ARCHIVE.ARCHIVED_SUCCESS` = "Conversation archived", `UNARCHIVED_SUCCESS` = "Conversation unarchived".
- pt_BR: "Arquivar" / "Desarquivar"; "Conversa arquivada" / "Conversa desarquivada".
- es: "Archivar" / "Desarchivar"; "Conversación archivada" / "Conversación desarchivada".

- [ ] **Step 3: Rodar o check de i18n**

Run: `ruby scripts/i18n/fork_translations.rb check` (se houver Ruby; senão valida na CI `fazer_ai_i18n.yml`).
Esperado: PASS (cobertura completa en/pt_BR/es).

- [ ] **Step 4: Commit**

```bash
git add app/javascript/dashboard/i18n/fazer-ai/locale
git commit --no-verify -m "i18n(conversations): add archive strings (en, pt_BR, es)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Registrar em "Mudanças nossas" + verificação final

**Files:**
- Modify: `.claude/CLAUDE.md` (seção "Mudanças nossas em arquivos do upstream")

- [ ] **Step 1: Registrar o recurso**

Acrescentar um item descrevendo: coluna `custom_archived`, edições em `conversation_finder.rb`, `conversation.rb` (`list_of_keys`), `_conversation.json.jbuilder`, `event_data_presenter.rb`, `config/routes.rb`, `conversation.js`, `helpers.js`, `actions.js`, `ChatList.vue`, `ConversationItem.vue`, `contextMenu/Index.vue`, `MoreActions.vue`; arquivos novos (controller, migration); i18n. Reverter = dropar a coluna, reverter as edições, apagar os arquivos novos. Apontar o design/plano em `docs/superpowers/`.

- [ ] **Step 2: Lint do front**

Run: `pnpm eslint app/javascript/dashboard/components/ChatList.vue app/javascript/dashboard/components/ConversationItem.vue app/javascript/dashboard/components/widgets/conversation/contextMenu/Index.vue app/javascript/dashboard/components/widgets/conversation/MoreActions.vue app/javascript/dashboard/store/modules/conversations/helpers.js app/javascript/dashboard/store/modules/conversations/actions.js app/javascript/dashboard/api/inbox/conversation.js`
Esperado: sem erros (atenção ao gotcha de CRLF no Windows).

- [ ] **Step 3: Suíte de front afetada**

Run: `pnpm test app/javascript/dashboard/store/modules/conversations/specs/helpers.spec.js app/javascript/dashboard/store/modules/conversations/specs/actions.spec.js`
Esperado: PASS.

- [ ] **Step 4: CI do backend (afetada)**

Run: `gh workflow run run_foss_spec.yml --ref feat/archived-conversations`
Esperado: verde (finder + controller + nada quebrado).

- [ ] **Step 5: Commit**

```bash
git add .claude/CLAUDE.md
git commit --no-verify -m "docs: register archived conversations in fork changes

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Verificação (HML)

Sem Ruby local e sem spec de componente para `ChatList`/`MoreActions`, a validação de ponta a ponta é em HML (`chatwoot-teste.willianramthun.store`) depois de cortar uma release `-custom.N` (fluxo de entrega padrão do fork):

1. Aba "Arquivadas" aparece ao lado de Minhas/Não atribuídas/Todos.
2. Arquivar pelo card (menu de contexto) → some das 3 abas normais, aparece em Arquivadas.
3. Arquivar pelo cabeçalho da conversa aberta → idem.
4. Badges de Minhas/Não atribuídas/Todos continuam contando só não-arquivadas.
5. Mensagem nova numa conversa arquivada → continua arquivada, não volta às abas normais, não vira não lida ali.
6. Desarquivar → volta ao fluxo com o status anterior (aberta/resolvida).
7. Tempo real: arquivar numa aba/aparelho → some nos outros sem recarregar (broadcast `conversation.updated`).
8. Grupos arquivam igual.

## Notas de risco

- **Contadores:** o endpoint `meta` (badges) não recebe `archived`, então os três contadores são sempre não-arquivados. Se algum dia o `meta` passar a receber `archived`, os badges quebram — manter `archived` fora de `ConversationApi.meta`.
- **Broadcast:** depende de `custom_archived` estar em `list_of_keys` (Task 2). Sem isso, arquivar não propaga em tempo real.
- **Ícone do menu:** confirmar que o nome de ícone usado existe no set do `MenuItem` (contextMenu usa nomes tipo `pin`, `delete`, `tag`); se `archive` não existir, usar um disponível.
