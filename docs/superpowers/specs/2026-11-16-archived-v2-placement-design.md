# Arquivadas v2 — reposicionar + contagem real — design

Data: 2026-11-16

## Contexto

A primeira versão de "Arquivar conversas"
(`2026-11-16-archived-conversations-design.md`) colocou "Arquivadas" como uma **4ª aba de
texto** na linha de Minhas/Não atribuídas/Todos, com um badge que mostra sempre "0" (o
`count` da aba é `undefined`, e o endpoint de contadores não devolve total de arquivadas).

O usuário achou que isso **poluiu** a linha de abas (que é de atribuição, não de escopo) e
quer: (1) a entrada na aba vira só um **ícone** com a **contagem real**; (2) um item
**"Arquivadas" na barra lateral**, dentro de "Conversas" (ao lado de Menções/Não atendidas);
(3) arquivadas passa a ser um **balde independente de status**.

## Decisões (confirmadas)

- **Ícone na própria linha das abas** (não botão separado): a entrada arquivadas deixa de ser
  texto e vira ícone de arquivo com tooltip "Arquivadas" + badge de contagem. Clicar ativa a
  visão como hoje.
- **Independente de status (balde à parte):** a visão de arquivadas mostra **todas** as
  arquivadas (abertas e resolvidas); o filtro de status não se aplica e o dropdown de status
  fica oculto/neutralizado nessa visão. O `archived_count` conta tudo que está arquivado,
  ignorando status e atribuição.
- **Sidebar e ícone fazem a mesma coisa** (abrem a mesma visão) — ok ter os dois.

## Escopo

### Dentro

1. `TabsItem` ganha suporte opcional a **ícone** (prop `icon`); a entrada arquivadas usa ícone
   em vez de texto, mantendo o badge.
2. A visão de arquivadas **ignora o status** (lista e contagem); o dropdown de status some
   quando ela está ativa.
3. Backend: finder devolve `archived_count` (total de arquivadas no escopo de
   caixa/time/etiqueta, ignorando status e atribuição), exposto no `meta`; store
   `conversationStats` guarda `archivedCount`; o badge do ícone lê isso.
4. Item **"Arquivadas"** no submenu "Conversas" da barra lateral, abrindo a mesma visão.

### Fora

- Mudar o comportamento de arquivar/desarquivar (menu do card e cabeçalho ficam como estão).
- Contagem de arquivadas por caixa/time separada do escopo atual (só o escopo da visão atual).

## Comportamento

- **Ícone na aba:** 4º item da linha, ícone de arquivo (ex.: `i-lucide-archive`), tooltip
  "Arquivadas", badge com `archivedCount`. Sem rótulo de texto, sem "0" fixo.
- **Badge sempre atualizado:** `archived_count` vem no payload de contadores (`meta`), que é
  buscado independentemente da aba ativa — então o número aparece certo mesmo em Minhas/Todos.
- **Visão de arquivadas:** ao ativar (pelo ícone ou pela sidebar), a lista mostra todas as
  arquivadas do escopo, **sem** filtro de status; o dropdown de status fica oculto. Ao sair,
  o status volta ao que estava.
- **Sidebar:** item "Arquivadas" em "Conversas"; clicar leva à visão de arquivadas (mesma
  lista). O item fica destacado quando a visão está ativa.

## Arquitetura

### Backend — `ConversationFinder`

- **Lista:** quando `params[:archived]` é verdadeiro, **não** aplicar `filter_by_status` (a
  visão ignora status). Hoje `filter_by_archived` já devolve só arquivadas; falta pular o
  status quando arquivado.
- **`archived_count`:** total de conversas **arquivadas** no escopo permitido (caixa/time/
  etiqueta/permissão), **ignorando status e atribuição**. **Cuidado:** hoje `set_up` aplica
  `filter_by_status` sobre `@conversations`, então os contadores mine/unassigned/all respeitam
  o status (correto para as abas normais). O `archived_count` **não** pode herdar esse status —
  precisa ser computado sobre o escopo **antes** do `filter_by_status` (capturar a relação base
  caixa/time/etiqueta/permissão/grupo antes do status, ou recomputar sem status) e então
  `.where(custom_archived: true).count`. Devolvido no hash `count` do `perform` e do
  `perform_meta_only`. (Os contadores mine/unassigned/all continuam como estão: não-arquivados,
  respeitando status.)
- Cuidar para o `filter_by_status` continuar valendo nas abas normais (não-arquivadas).

### Backend — payload de contadores

- `app/views/api/v1/conversations/index` (meta) e o `_conversation` list meta: incluir
  `json.archived_count`.
- `ConversationApi.meta` não precisa mudar (continua sem mandar `archived`); o `archived_count`
  é só mais um número no retorno.

### Frontend

- **`conversationStats` store:** guardar `archivedCount` (de `SET_CONV_TAB_META`), getter expõe.
- **`ChatList` / `ChatTypeTabs` / `TabsItem`:**
  - `assigneeTabItems`: a entrada arquivadas passa `icon` + `count: archivedCount` (sem `name`
    visível, mas com rótulo acessível/tooltip "Arquivadas").
  - `TabsItem`: prop `icon` opcional; renderiza o ícone no lugar do `{{ name }}` quando
    presente, mantém o badge. Edição aditiva (prop nova, default sem ícone → comportamento
    atual).
  - `conversationFilters`: na visão arquivadas, não enviar `status` (ou enviar `all`) e manter
    `archived: true`, `assigneeType: 'archived'` (ver gotcha da chave de paginação por aba).
  - `applyPageFilters`: na visão arquivadas, o filtro de status em memória também deve tratar
    como "todos" (já que `status` não é enviado/`all`).
  - Ocultar/neutralizar o dropdown de status quando a visão arquivadas está ativa.
- **Sidebar (`components-next/sidebar/Sidebar.vue`):** item "Arquivadas" no submenu "Conversas";
  rota que ativa a visão arquivadas (seguir o padrão de Menções/Não atendidas). Destaque quando
  ativo. i18n `SIDEBAR`/conversas no overlay.

## Gotchas conhecidos a respeitar

- **Chave de paginação por aba** (ver memória `chatlist-tab-key-pagination`): a visão arquivadas
  deve enviar `assigneeType: 'archived'` (bate com a chave de bookkeeping de página/fim-de-lista),
  nunca `'all'`, e `page` nunca pode virar `NaN` (`(currentPage || 0) + 1`). Esta mudança **não
  pode regredir** esse fix.
- Contadores sempre não-arquivados para mine/unassigned/all; `archived_count` é um número à parte.

## i18n

- Chaves novas (ícone/tooltip "Arquivadas" se precisar de rótulo acessível; item da sidebar) em
  **en, pt_BR, es** no overlay. Reusar `CHAT_LIST.ASSIGNEE_TYPE_TABS.ARCHIVED` como tooltip/label.

## Testes

- **Finder:** `archived=true` ignora status (arquivada resolvida aparece quando `status=open`);
  `archived_count` conta todas as arquivadas do escopo ignorando status/atribuição; contadores
  mine/unassigned/all seguem não-arquivados.
- **Store:** `conversationStats` expõe `archivedCount` a partir do meta.
- **TabsItem:** renderiza ícone quando `icon` presente (mantendo badge); texto quando ausente.
- **ChatList/sidebar:** validação em HML (sem spec de componente para `ChatList`/`Sidebar`).

## Entrega

Nova branch `feat/archived-v2-placement` → spec → plano → implementação (subagent-driven) → CI
→ PR/merge squash → **release `custom.28`** → imagem → HML.

## Reverter

Tirar a prop `icon` do `TabsItem`, voltar a entrada da aba para texto, remover `archived_count`
do finder/meta/store, remover o item da sidebar e a independência de status. (A v1 continua
funcionando sem isso.)
