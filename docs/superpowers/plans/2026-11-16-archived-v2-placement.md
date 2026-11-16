# Arquivadas v2 (ícone + contagem real + sidebar) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tirar "Arquivadas" da linha de abas de atribuição: vira um ícone com a contagem real de arquivadas, a visão passa a ignorar o status (balde à parte), e ganha um item próprio no submenu "Conversas" da barra lateral.

**Architecture:** O `ConversationFinder` passa a devolver `archived_count` (total de arquivadas ignorando status/atribuição) e a servir a lista de arquivadas sem filtro de status, mantendo os contadores mine/unassigned/all como estão (não-arquivados, com status). No front, a 4ª entrada da linha de abas vira ícone (`TabsItem` ganha prop `icon`) com badge vindo do `archivedCount`; a visão de arquivadas some com o dropdown de status; e uma rota nova `conversation_archived` (prop no `ConversationView` → `ChatList`) é linkada por um item na sidebar.

**Tech Stack:** Rails 7 (ActiveRecord, Jbuilder, RSpec), Vue 3 `<script setup>` + Vuex, vue-i18n, Vitest.

## Global Constraints

- **Fork, merge barato:** preferir arquivos novos; editar upstream só o mínimo e registrar em `.claude/CLAUDE.md` → "Mudanças nossas". Namespace/prefixo `custom`.
- **Sem Ruby/Postgres local:** specs de backend validam **só na CI** (`gh workflow run run_foss_spec.yml --ref <branch> -f specs="..."`); não rodar `rspec`/`rails` local. Frontend roda local: `pnpm test <arquivo>` (nunca `pnpm test -- <arquivo>`), `npx eslint <arquivo>` (o `pnpm eslint` roda glob do repo).
- **Commits com `--no-verify`** (husky pre-commit chama `bundle`, que não existe). **Sempre `git add <arquivo específico>`, nunca `-A`/`.`** (o repo tem milhares de diffs-fantasma de CRLF). Mensagens Conventional Commits terminando com `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **i18n:** chaves novas em **en, pt_BR e es**, sempre no overlay `app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/<arquivo>.json` (os arquivos de namespace upstream já existem no overlay — mesclar, não recriar).
- **Gotcha chave de paginação por aba:** a visão arquivadas **tem que** enviar `assigneeType: 'archived'` (bate com a chave de bookkeeping de página/fim-de-lista), nunca `'all'`; e `page` nunca pode virar `NaN` (`(currentPage || 0) + 1`). Não regredir o fix do loop (commits `3ec6ca176`/`a036aae69` na v1).
- **Contadores mine/unassigned/all são sempre não-arquivados e respeitam status.** `archived_count` é um número à parte que ignora status e atribuição.
- Branch já criada: `feat/archived-v2-placement` (a partir da `main`).
- Tailwind only; Composition API `<script setup>`; eventos camelCase; componentes PascalCase.

---

## File Structure

**Backend (upstream, edição mínima):**
- `app/finders/conversation_finder.rb` — reordenar `set_up` (status por último + snapshot `@archived_count_scope`), `archived_count`, lista arquivada sem status, `archived_count` no hash de contadores.
- `app/views/api/v1/accounts/conversations/meta.json.jbuilder` e `.../index.json.jbuilder` — `json.archived_count`.
- `app/javascript/dashboard/store/modules/conversationStats.js` — guardar/expor `archivedCount`.
- `app/javascript/dashboard/store/mutation-types` (via `SET_CONV_TAB_META`) — nenhum tipo novo (reusa a mutation).
- `app/javascript/dashboard/components/ui/Tabs/TabsItem.vue` — prop `icon` opcional.
- `app/javascript/dashboard/components/widgets/ChatTypeTabs.vue` — repassar `icon`.
- `app/javascript/dashboard/components/ChatList.vue` — item arquivadas como ícone+`archivedCount`; visão arquivadas sem status; esconder dropdown de status; aceitar prop `archived` (da rota) pra forçar a aba.
- `app/javascript/dashboard/routes/dashboard/conversation/conversation.routes.js` — rotas `conversation_archived` + `conversation_through_archived`.
- `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` — repassar prop `archived`.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` — item "Arquivadas" em "Conversas".

**Overlay i18n:**
- `fazer-ai/locale/{en,pt_BR,es}/settings.json` (ou o arquivo que tem `SIDEBAR.*`) — `SIDEBAR.ARCHIVED_CONVERSATIONS`.

**Specs:**
- `spec/finders/conversation_finder_spec.rb` — archived ignora status + `archived_count`.
- `app/javascript/dashboard/store/modules/specs/conversationStats/...` — `archivedCount`.
- `app/javascript/dashboard/components/ui/Tabs/` — spec do `TabsItem` ícone (se houver pasta de specs; senão criar `specs/TabsItem.spec.js`).

---

## Task 1: Finder — `archived_count` + lista arquivada sem status

**Files:**
- Modify: `app/finders/conversation_finder.rb`
- Modify: `app/views/api/v1/accounts/conversations/meta.json.jbuilder`
- Modify: `app/views/api/v1/accounts/conversations/index.json.jbuilder`
- Test: `spec/finders/conversation_finder_spec.rb`

**Interfaces:**
- Produces: hash de contadores ganha `archived_count` (Integer). A lista, quando `params[:archived]` é verdadeiro, ignora o filtro de status. Contadores mine/unassigned/all inalterados (não-arquivados, com status). `meta`/`index` jbuilder expõem `archived_count`.

- [ ] **Step 1: Escrever os exemplos que falham** (adaptar aos `let`/factories reais do arquivo)

```ruby
  describe 'archived view ignores status and archived_count' do
    let!(:archived_open) do
      create(:conversation, account: account, inbox: inbox, assignee: user_1, status: :open, custom_archived: true)
    end
    let!(:archived_resolved) do
      create(:conversation, account: account, inbox: inbox, assignee: user_1, status: :resolved, custom_archived: true)
    end

    it 'returns archived conversations of any status, even with status=open' do
      result = described_class.new(user_1, { archived: 'true', status: 'open' }).perform
      expect(result[:conversations]).to contain_exactly(archived_open, archived_resolved)
    end

    it 'reports archived_count ignoring status' do
      result = described_class.new(user_1, { assignee_type: 'me', status: 'open' }).perform
      expect(result[:count][:archived_count]).to eq(2)
    end

    it 'keeps mine/all counts non-archived' do
      non_archived = create(:conversation, account: account, inbox: inbox, assignee: user_1, status: :open, custom_archived: false)
      result = described_class.new(user_1, { assignee_type: 'me', status: 'open' }).perform
      expect(result[:count][:all_count]).to eq(
        Conversations::PermissionFilterService.new(
          account.conversations.where(custom_archived: false, status: :open), user_1, account
        ).perform.count
      )
      expect(result[:conversations]).to include(non_archived)
    end
  end
```

- [ ] **Step 2: Rodar (CI) e ver falhar**

`gh workflow run run_foss_spec.yml --ref feat/archived-v2-placement -f specs="spec/finders/conversation_finder_spec.rb"`. Esperado: FAIL (`archived_count` ausente; lista arquivada filtra status).

- [ ] **Step 3: Implementar no finder**

Reordenar `set_up` para aplicar o status **por último** e guardar o escopo pré-status:

```ruby
  def set_up
    set_inboxes
    set_team
    set_assignee_type

    find_all_conversations
    filter_by_group_type
    filter_by_team
    filter_by_labels
    filter_by_query
    filter_by_source_id
    # Snapshot before status: archived_count and the archived list ignore status (archived is a
    # bucket of its own), while mine/unassigned/all keep respecting it.
    @archived_count_scope = @conversations
    filter_by_status unless params[:q]
  end
```

`perform` passa a computar `archived_count`, trocar o escopo da lista quando arquivado, e devolver o número:

```ruby
  def perform
    set_up

    mine_count, unassigned_count, all_count = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count
    archived = archived_count

    # The archived list is status-independent: swap back to the pre-status scope before narrowing
    # to archived. Counts above were already taken over the status-filtered scope, so the badges stay correct.
    @conversations = @archived_count_scope if filter_archived?
    filter_by_archived
    filter_by_assignee_type

    {
      conversations: conversations,
      count: {
        mine_count: mine_count,
        assigned_count: assigned_count,
        unassigned_count: unassigned_count,
        all_count: all_count,
        archived_count: archived
      }
    }
  end
```

`perform_meta_only` também devolve `archived_count`:

```ruby
  def perform_meta_only
    set_up

    mine_count, unassigned_count, all_count, = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count

    {
      count: {
        mine_count: mine_count,
        assigned_count: assigned_count,
        unassigned_count: unassigned_count,
        all_count: all_count,
        archived_count: archived_count
      }
    }
  end
```

Métodos privados novos (junto dos outros `filter_by_*`/counts):

```ruby
  def filter_archived?
    ActiveModel::Type::Boolean.new.cast(params[:archived]) || false
  end

  def archived_count
    @archived_count_scope.where(custom_archived: true).count
  end
```

E `filter_by_archived` reusa o predicado (sem mudar o comportamento):

```ruby
  def filter_by_archived
    @conversations = @conversations.where(custom_archived: filter_archived?)
  end
```

- [ ] **Step 4: Expor no jbuilder**

Em `meta.json.jbuilder` e no bloco `meta` do `index.json.jbuilder`, após `json.all_count ...`:

```ruby
  json.archived_count @conversations_count[:archived_count]
```

- [ ] **Step 5: Rodar (CI) e ver passar**

`gh workflow run run_foss_spec.yml --ref feat/archived-v2-placement -f specs="spec/finders/conversation_finder_spec.rb"`. Esperado: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/finders/conversation_finder.rb app/views/api/v1/accounts/conversations/meta.json.jbuilder app/views/api/v1/accounts/conversations/index.json.jbuilder spec/finders/conversation_finder_spec.rb
git commit --no-verify -m "feat(conversations): status-independent archived list and archived_count

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Store — `archivedCount` em `conversationStats`

**Files:**
- Modify: `app/javascript/dashboard/store/modules/conversationStats.js`
- Test: `app/javascript/dashboard/store/modules/specs/conversationStats/conversationStats.spec.js` (ou o spec existente do módulo)

**Interfaces:**
- Consumes: `archived_count` no `meta` (Task 1).
- Produces: estado `archivedCount` + getter `getStats` já expõe o estado inteiro (então `getStats.value.archivedCount`). A mutation `SET_CONV_TAB_META` passa a ler `archived_count`.

- [ ] **Step 1: Teste que falha**

No spec do `conversationStats` (ler o arquivo pra casar o estilo), asserir que a mutation `SET_CONV_TAB_META` grava `archivedCount`:

```js
it('stores archivedCount from the meta payload', () => {
  const state = { mineCount: 0, unAssignedCount: 0, allCount: 0, archivedCount: 0 };
  mutations[types.SET_CONV_TAB_META](state, {
    mine_count: 1, unassigned_count: 2, all_count: 3, archived_count: 7,
  });
  expect(state.archivedCount).toBe(7);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `pnpm test app/javascript/dashboard/store/modules/specs/conversationStats/conversationStats.spec.js`
Esperado: FAIL (archivedCount indefinido).

- [ ] **Step 3: Implementar**

Em `conversationStats.js`: adicionar `archivedCount: 0` ao `state`, e na mutation `SET_CONV_TAB_META` destructar e gravar:

```js
const state = {
  mineCount: 0,
  unAssignedCount: 0,
  allCount: 0,
  archivedCount: 0,
};
```

```js
  [types.SET_CONV_TAB_META](
    $state,
    {
      mine_count: mineCount,
      unassigned_count: unAssignedCount,
      all_count: allCount,
      archived_count: archivedCount = 0,
    } = {}
  ) {
    $state.mineCount = mineCount;
    $state.allCount = allCount;
    $state.unAssignedCount = unAssignedCount;
    $state.archivedCount = archivedCount;
    $state.updatedOn = new Date();
  },
```

- [ ] **Step 4: Rodar e ver passar**

Run: `pnpm test app/javascript/dashboard/store/modules/specs/conversationStats/conversationStats.spec.js`
Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/store/modules/conversationStats.js app/javascript/dashboard/store/modules/specs/conversationStats/conversationStats.spec.js
git commit --no-verify -m "feat(conversations): track archivedCount in conversation stats

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Aba arquivadas vira ícone com contagem real

**Files:**
- Modify: `app/javascript/dashboard/components/ui/Tabs/TabsItem.vue`
- Modify: `app/javascript/dashboard/components/widgets/ChatTypeTabs.vue`
- Modify: `app/javascript/dashboard/components/ChatList.vue` (`assigneeTabItems`)
- Test: `app/javascript/dashboard/components/ui/Tabs/specs/TabsItem.spec.js`

**Interfaces:**
- Consumes: `archivedCount` (Task 2).
- Produces: `TabsItem` renderiza um ícone (via prop `icon`, nome estilo `i-lucide-archive`) no lugar do `{{ name }}` quando presente, mantendo o badge; `ChatTypeTabs` repassa `icon`; a entrada arquivadas do `ChatList` usa `icon` + `count: archivedCount` e `showBadge` só quando `archivedCount > 0`.

- [ ] **Step 1: Teste que falha (TabsItem ícone)**

Criar `app/javascript/dashboard/components/ui/Tabs/specs/TabsItem.spec.js`:

```js
import { mount } from '@vue/test-utils';
import TabsItem from '../TabsItem.vue';

const provide = { activeIndex: { value: 0 }, updateActiveIndex: () => {} };

describe('TabsItem', () => {
  it('renders an icon span when icon prop is set', () => {
    const wrapper = mount(TabsItem, {
      props: { index: 0, name: 'Arquivadas', icon: 'i-lucide-archive' },
      global: { provide },
    });
    expect(wrapper.find('.i-lucide-archive').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('Arquivadas');
  });

  it('renders the name when no icon', () => {
    const wrapper = mount(TabsItem, {
      props: { index: 0, name: 'Minhas' },
      global: { provide },
    });
    expect(wrapper.text()).toContain('Minhas');
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `pnpm test app/javascript/dashboard/components/ui/Tabs/specs/TabsItem.spec.js`
Esperado: FAIL (sem suporte a ícone).

- [ ] **Step 3: Implementar `TabsItem`**

Adicionar a prop `icon` e renderizar ícone no lugar do nome quando presente (mantendo tooltip com `name`):

```js
  icon: {
    type: String,
    default: '',
  },
```

No template, trocar a linha `{{ name }}` por:

```html
      <span v-if="icon" v-tooltip="name" :class="icon" class="size-4" />
      <template v-else>{{ name }}</template>
```

(O `v-tooltip` é global no dashboard; se o teste não registrar a diretiva, o mount com `global.directives` deve stubar — ver como outros specs de componentes do dashboard lidam; se precisar, adicionar `directives: { tooltip: () => {} }` no `global` do spec.)

- [ ] **Step 4: Repassar `icon` no `ChatTypeTabs`**

Em `ChatTypeTabs.vue`, no `<woot-tabs-item>`, adicionar `:icon="item.icon"`:

```html
    <woot-tabs-item
      v-for="(item, index) in items"
      :key="item.key"
      class="text-sm [&_a]:font-medium"
      :index="index"
      :name="item.name"
      :icon="item.icon"
      :count="item.count"
      :show-badge="item.showBadge !== false"
      is-compact
    />
```

- [ ] **Step 5: Entrada arquivadas do `ChatList` usa ícone + contagem**

Em `ChatList.vue`, ler o getter de stats (já existe `conversationStats`) e montar a entrada arquivadas com ícone + contagem real, badge só quando > 0:

```js
const archivedCount = computed(() => conversationStats.value.archivedCount || 0);
```

No `assigneeTabItems`, trocar o push da entrada arquivadas:

```js
  items.push({
    key: ARCHIVED_TAB,
    name: t('CHAT_LIST.ASSIGNEE_TYPE_TABS.ARCHIVED'),
    icon: 'i-lucide-archive',
    count: archivedCount.value,
    showBadge: archivedCount.value > 0,
  });
```

- [ ] **Step 6: Rodar e ver passar**

Run: `pnpm test app/javascript/dashboard/components/ui/Tabs/specs/TabsItem.spec.js`
Esperado: PASS. Lint: `npx eslint app/javascript/dashboard/components/ui/Tabs/TabsItem.vue app/javascript/dashboard/components/widgets/ChatTypeTabs.vue app/javascript/dashboard/components/ChatList.vue` (ignorar ruído CRLF de outros arquivos; se um dos NOSSOS acusar CRLF, `npx eslint <arquivo> --fix`).

- [ ] **Step 7: Commit**

```bash
git add app/javascript/dashboard/components/ui/Tabs/TabsItem.vue app/javascript/dashboard/components/widgets/ChatTypeTabs.vue app/javascript/dashboard/components/ChatList.vue app/javascript/dashboard/components/ui/Tabs/specs/TabsItem.spec.js
git commit --no-verify -m "feat(conversations): archived tab as icon with real count badge

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Visão arquivadas ignora status + esconde dropdown de status

**Files:**
- Modify: `app/javascript/dashboard/components/ChatList.vue`

**Interfaces:**
- Consumes: `ARCHIVED_TAB`, `activeAssigneeTab` (já existem).
- Produces: na visão arquivadas, `conversationFilters.status` vira `undefined` (sem filtro de status; o backend ignora status p/ archived e o `applyPageFilters` trata como "todos"); o controle de status (dropdown "Abertas/…") não é renderizado quando a visão arquivadas está ativa.

- [ ] **Step 1: `conversationFilters` dropa status na visão arquivadas**

No computed `conversationFilters` do `ChatList.vue`, ajustar `status`:

```js
    status:
      activeAssigneeTab.value === ARCHIVED_TAB ? undefined : activeStatus.value,
```

(`assigneeType: activeAssigneeTab.value` e `archived: ... ? true : undefined` continuam como estão — não regredir o fix do loop.)

- [ ] **Step 2: Esconder o controle de status quando arquivadas ativa**

Localizar no template o filtro básico de status (o seletor que usa `onBasicFilterChange(..., 'status')`/`activeStatus`) e envolvê-lo num `v-if` que o esconde na visão arquivadas. Definir um helper:

```js
const isArchivedView = computed(() => activeAssigneeTab.value === ARCHIVED_TAB);
```

e no template adicionar `v-if="!isArchivedView"` ao elemento do dropdown de status (apenas o de status; manter o de ordenação/sort).

- [ ] **Step 3: Verificação**

Sem spec de componente para `ChatList` — validar em HML (ver seção Verificação). Conferir: na aba arquivadas, lista mostra arquivadas de qualquer status e o dropdown de status some; nas abas normais o dropdown volta e o status filtra.

- [ ] **Step 4: Lint + Commit**

`npx eslint app/javascript/dashboard/components/ChatList.vue` (ignorar ruído de outros arquivos).

```bash
git add app/javascript/dashboard/components/ChatList.vue
git commit --no-verify -m "feat(conversations): archived view ignores status filter

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Rota `conversation_archived` + prop no `ConversationView`/`ChatList`

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/conversation/conversation.routes.js`
- Modify: `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue`
- Modify: `app/javascript/dashboard/components/ChatList.vue`

**Interfaces:**
- Produces: rotas nomeadas `conversation_archived` (lista) e `conversation_through_archived` (lista + conversa aberta), que passam `archived: true` ao `ConversationView`; o `ConversationView` repassa `archived` ao `ChatList`; o `ChatList`, com `props.archived`, inicia na aba arquivadas.

- [ ] **Step 1: Rotas** (seguir o padrão de `conversation_unattended`)

Em `conversation.routes.js`, dentro do mesmo array de rotas, adicionar:

```js
    {
      path: frontendURL('accounts/:accountId/archived/conversations'),
      name: 'conversation_archived',
      meta: { permissions: CONVERSATION_PERMISSIONS },
      component: ConversationView,
      props: () => ({ archived: true }),
    },
    {
      path: frontendURL('accounts/:accountId/archived/conversations/:conversationId'),
      name: 'conversation_through_archived',
      meta: { permissions: CONVERSATION_PERMISSIONS },
      component: ConversationView,
      props: route => ({ conversationId: route.params.conversationId, archived: true }),
    },
```

- [ ] **Step 2: `ConversationView` aceita e repassa `archived`**

Em `ConversationView.vue`, adicionar a prop `archived` (Boolean, default false) e passá-la ao `ChatList`/`ConversationList` que ele renderiza:

```js
  archived: { type: Boolean, default: false },
```

e no template, no componente de lista (onde já passa `conversation-type`/`folders-id`), adicionar `:archived="archived"`.

- [ ] **Step 3: `ChatList` aceita `archived` e inicia na aba arquivadas**

Em `ChatList.vue`, adicionar a prop:

```js
  archived: { type: Boolean, default: false },
```

e inicializar o `activeAssigneeTab` na aba arquivadas quando a prop vier true. Onde `activeAssigneeTab` é declarado (`const activeAssigneeTab = ref(wootConstants.ASSIGNEE_TYPE.ME);`), trocar por:

```js
const activeAssigneeTab = ref(
  props.archived ? ARCHIVED_TAB : wootConstants.ASSIGNEE_TYPE.ME
);
```

e, para cobrir navegação entre rotas sem remount, observar a prop:

```js
watch(
  () => props.archived,
  isArchived => {
    if (isArchived && activeAssigneeTab.value !== ARCHIVED_TAB) {
      updateAssigneeTab(ARCHIVED_TAB);
    }
  }
);
```

(`updateAssigneeTab` já existe e cuida do fetch/estado.)

- [ ] **Step 4: Verificação**

Sem spec de componente — validar em HML: abrir `/accounts/2/archived/conversations` (ou o item da sidebar da Task 6) cai na visão arquivadas.

- [ ] **Step 5: Lint + Commit**

`npx eslint app/javascript/dashboard/routes/dashboard/conversation/conversation.routes.js app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue app/javascript/dashboard/components/ChatList.vue`

```bash
git add app/javascript/dashboard/routes/dashboard/conversation/conversation.routes.js app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue app/javascript/dashboard/components/ChatList.vue
git commit --no-verify -m "feat(conversations): dedicated archived conversations route

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Item "Arquivadas" no submenu "Conversas" da sidebar

**Files:**
- Modify: `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`

**Interfaces:**
- Consumes: rota `conversation_archived` (Task 5), `archivedCount` getter (Task 2).
- Produces: item "Arquivadas" como filho de "Conversas", linkando à rota, destacado quando ativo, com o total de arquivadas no contador do item.

- [ ] **Step 1: Ler o getter de stats no Sidebar**

Em `Sidebar.vue`, perto dos outros `useMapGetter` (ex.: `unattendedUnreadCount`), adicionar:

```js
const conversationStats = useMapGetter('conversationStats/getStats');
```

- [ ] **Step 2: Adicionar o item filho em "Conversas"**

No array `children` do item "Conversas" (depois do item de "Não atendidas"/`conversation_unattended`), adicionar — seguindo o shape dos vizinhos (`label`, `activeOn`, `to`, e um contador opcional):

```js
        {
          name: 'Archived',
          activeOn: ['conversation_through_archived'],
          label: t('SIDEBAR.ARCHIVED_CONVERSATIONS'),
          icon: 'i-lucide-archive',
          badgeCount: conversationStats.value.archivedCount || 0,
          to: accountScopedRoute('conversation_archived'),
        },
```

Shape confirmado igual ao item "Unattended" vizinho (`name`, `activeOn`, `label`, `icon`,
`badgeCount`, `to`). O contador do item da sidebar é `badgeCount` (não `count`).

- [ ] **Step 3: Verificação**

Sem spec — validar em HML: o item "Arquivadas" aparece em Conversas, abre a visão arquivadas e fica destacado.

- [ ] **Step 4: Lint + Commit**

`npx eslint app/javascript/dashboard/components-next/sidebar/Sidebar.vue`

```bash
git add app/javascript/dashboard/components-next/sidebar/Sidebar.vue
git commit --no-verify -m "feat(conversations): add Archived entry to the sidebar Conversations menu

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: i18n `SIDEBAR.ARCHIVED_CONVERSATIONS` (en/pt_BR/es)

**Files:**
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/settings.json`

**Interfaces:**
- Produces: `SIDEBAR.ARCHIVED_CONVERSATIONS` nos 3 idiomas.

As chaves de nav da sidebar (`SIDEBAR.UNATTENDED_CONVERSATIONS` etc.) ficam em `settings.json`
upstream; o overlay `fazer-ai/locale/<locale>/settings.json` **já existe e já tem um objeto
`SIDEBAR`** (da feature "Painel", chave `SIDEBAR.PANEL`). Mesclar a chave nova no `SIDEBAR`
existente, sem recriar o objeto.

- [ ] **Step 1: Adicionar a chave nos 3 idiomas**

Sob `SIDEBAR` (no `settings.json` de cada locale do overlay):
- en: `"ARCHIVED_CONVERSATIONS": "Archived"`
- pt_BR: `"ARCHIVED_CONVERSATIONS": "Arquivadas"`
- es: `"ARCHIVED_CONVERSATIONS": "Archivadas"`

- [ ] **Step 2: Validar JSON**

`node -e "JSON.parse(require('fs').readFileSync('<path>','utf8'))"` em cada `settings.json` alterado. (Cobertura Ruby `fork_translations.rb check` roda na CI.)

- [ ] **Step 3: Commit** (listar os 3 arquivos)

```bash
git add app/javascript/dashboard/i18n/fazer-ai/locale/en/settings.json app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/settings.json app/javascript/dashboard/i18n/fazer-ai/locale/es/settings.json
git commit --no-verify -m "i18n(conversations): archived sidebar entry (en, pt_BR, es)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Registrar em "Mudanças nossas" + verificação final

**Files:**
- Modify: `.claude/CLAUDE.md`

- [ ] **Step 1: Atualizar o registro**

Atualizar/estender o item de "Arquivar conversas" na seção "## Mudanças nossas em arquivos do upstream" com a v2: `archived_count` no finder/meta, lista arquivada sem status, `archivedCount` no `conversationStats`, prop `icon` no `TabsItem` + repasse no `ChatTypeTabs`, entrada arquivadas como ícone no `ChatList`, visão sem status + esconder dropdown, rotas `conversation_archived`/`conversation_through_archived` + prop `archived` no `ConversationView`/`ChatList`, item na sidebar, i18n `SIDEBAR.ARCHIVED_CONVERSATIONS`. Apontar o design/plano v2 em `docs/superpowers/`.

- [ ] **Step 2: Lint dos arquivos nossos**

`npx eslint` nos arquivos JS/Vue tocados (lista das Tasks 2–7). Reportar só erros dos NOSSOS arquivos.

- [ ] **Step 3: Suíte de front afetada**

`pnpm test app/javascript/dashboard/store/modules/specs/conversationStats/conversationStats.spec.js app/javascript/dashboard/components/ui/Tabs/specs/TabsItem.spec.js`
Esperado: PASS.

- [ ] **Step 4: CI backend afetada**

`gh workflow run run_foss_spec.yml --ref feat/archived-v2-placement -f specs="spec/finders/conversation_finder_spec.rb"`
Esperado: verde.

- [ ] **Step 5: Commit**

```bash
git add .claude/CLAUDE.md
git commit --no-verify -m "docs: register archived v2 in fork changes

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Verificação (HML)

Depois de cortar `custom.28` e subir no HML:

1. A entrada arquivadas na linha de abas é **um ícone** (não mais "Arquivadas 0"), com badge só quando há arquivadas, mostrando o **total real**.
2. O badge do ícone fica certo mesmo estando em Minhas/Todos (vem do `meta`).
3. Clicar no ícone abre a visão arquivadas: lista **todas** as arquivadas (abertas e resolvidas) e o **dropdown de status some**.
4. Os badges de Minhas/Não atribuídas/Todos continuam com os números não-arquivados, respeitando o status.
5. O item **"Arquivadas"** aparece no submenu "Conversas" da barra lateral, abre a mesma visão e fica destacado; mostra o total.
6. Não há loop de refetch (regressão do fix v1) em nenhuma das entradas.
7. Arquivar/desarquivar (card e cabeçalho) continua funcionando e o total do badge atualiza.

## Notas de risco

- **Não regredir o fix do loop:** `assigneeType` da visão arquivadas tem que ser `'archived'` e `page` nunca `NaN`. Conferir no HML a aba de rede: uma request `...&assignee_type=archived&...&archived=true`, sem enxurrada.
- **Contadores:** mine/unassigned/all sempre não-arquivados e com status; `archived_count` ignora status/atribuição. Se algum virar status-less ou arquivado, o cálculo no finder está errado.
- **`TabsItem` é compartilhado:** a prop `icon` é aditiva (default vazio → comportamento atual). Conferir que as outras abas (sem `icon`) seguem idênticas.
