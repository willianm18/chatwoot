# Kanban — refinamento visual + múltiplos responsáveis

- **Data:** 2026-11-10
- **Autor:** Willian (via brainstorming)
- **Status:** aprovado, aguardando revisão da spec antes do plano

## Objetivo

Reescrever o visual do Kanban nativo (Tarefas de equipe) para uma leitura estilo
Trello, e substituir o responsável único por **múltiplos responsáveis**. Três
telas mudam: o **card na coluna**, o **detalhe do card** (diálogo) e o
**cabeçalho da coluna + barra de topo**. É uma evolução da feature existente
(ver `2026-11-09-kanban-team-tasks-design.md` e a fase 2), não um recurso novo —
mantém o namespace `Custom::Kanban::*`, o controle de acesso por quadro e o tempo
real já existentes.

## Decisões (do brainstorming)

1. **Quem pode ser responsável:** apenas **membros do quadro ou o dono** (não
   qualquer agente da conta, como era antes).
2. **Card na coluna:** etiquetas viram **pills coloridas com o nome** (não barras
   de cor); **múltiplos responsáveis** como avatares empilhados no rodapé; badge
   de **prazo** que fica vermelho quando vencido; ícones de descrição /
   comentários / anexos quando houver.
3. **Detalhe do card:** modal **largo em duas colunas**. Esquerda = card
   (responsáveis · etiquetas · prazo · descrição · anexos). Direita = **thread de
   comentários** fixa, com campo de escrever embaixo. Título e descrição
   **editáveis ao clicar** (inline). Em telas estreitas colapsa para uma coluna,
   comentários embaixo.
4. **Cabeçalho da coluna:** nome + **contador de cards** + botão `＋` para
   adicionar card no topo da coluna (além do "+ Novo card" no rodapé).
5. **Barra de topo:** filtros de responsável e etiqueta restilizados + atalho
   **"Meus cards"** (cards onde o usuário atual é um dos responsáveis).

## Modelo de dados — múltiplos responsáveis

Segue o padrão de `card_labels` já usado pela feature.

- **Nova tabela** `custom_kanban_card_assignees`:
  - `custom_kanban_card_id` (bigint, not null, index)
  - `user_id` (bigint, not null)
  - índice único em `[custom_kanban_card_id, user_id]` (evita responsável
    duplicado no mesmo card)
  - `created_at` / `updated_at`
- **Novo model** `Custom::Kanban::CardAssignee` (`table_name =
  'custom_kanban_card_assignees'`), `belongs_to :card` e `belongs_to :user`.
- **No `Custom::Kanban::Card`:**
  - remover `belongs_to :assignee` (coluna única);
  - `has_many :card_assignees, dependent: :destroy` e
    `has_many :assignees, through: :card_assignees, source: :user`;
  - validação de que todo `assignee` é membro do quadro ou o dono (ver abaixo).
- **Migration idempotente** (`bundle exec rails g migration`, timestamp real):
  1. cria `custom_kanban_card_assignees` só se a tabela não existir;
  2. **backfill:** para cada card com `assignee_id` presente, cria o
     `card_assignee` correspondente (em Ruby/ActiveRecord, `find_each`, sem SQL
     cru), idempotente (não duplica se já existir);
  3. remove a coluna `assignee_id` de `custom_kanban_cards` se existir.
  - `db/schema.rb` editado à mão (não há Ruby local): nova tabela + nova versão.
    **Um dev com Ruby roda `bundle exec rails db:migrate` e confere que o schema
    regenerado é idêntico** antes do merge.

### Validação de pertencimento

A regra "responsável só pode ser membro do quadro ou o dono" é verificada no
**model** (`validate`) e no **controller** (parâmetros). Reaproveitar a noção de
membro que o quadro já expõe (`board_members` + `owner`). Entrada inválida →
`422`, reusando os erros existentes (padrão do `AGENTS.md`), não deixa chegar a
estado inconsistente.

## Payload / API

- **`_card.json.jbuilder`:** trocar `json.assignee_id` por
  `json.assignee_ids card.assignees.map(&:id)` (mesmo espírito de `label_ids`).
  O front resolve id → agente (nome/avatar/cor) com a lista de agentes que a tela
  já carrega (`agents/getAgents`); membros são um subconjunto dos agentes.
- **Cards controller (create/update):** aceitar `assignee_ids` (array) em vez de
  `assignee_id`; strong params; validar pertencimento. Substituir o conjunto de
  responsáveis do card pelo array recebido.
- **Store/API JS (`dashboard/api/custom/kanban.js`, `store/modules/custom/
  kanban.js`):** `createCard`/`updateCard` enviam `assignee_ids`; os getters/
  filtros passam a usar `assignee_ids`.

## Frontend

Tailwind only, `components-next`, tokens `n-*` (regra do `AGENTS.md`). Avatares
usam o componente de avatar existente do design system (avatar do agente com
fallback de iniciais). Princípios do `frontend-design` aplicados dentro do DS:
hierarquia clara, conter a ousadia, revisar por screenshot.

### `KanbanCard.vue` (card na coluna) — opção B aprovada

- Etiquetas como **pills com nome** (cor de fundo = `label.color`, texto branco),
  com quebra de linha.
- Título.
- Rodapé (só aparece quando há conteúdo): à esquerda badge de **prazo**
  (formatado "14 nov", vermelho quando vencido) + ícones de descrição /
  contagem de comentários / contagem de anexos quando existirem; à direita
  **avatares empilhados** dos responsáveis (resolvidos de `assignee_ids`).
- Resolver `assignee_ids` → agentes: a `BoardView` passa os agentes (ou um mapa
  id→agente) ao card, como já passa `labels`.

### `CardDialog.vue` (detalhe) — modal largo, duas colunas

- Cabeçalho: título (editável inline) + "na coluna X".
- Coluna esquerda: **Responsáveis** (avatares + botão `＋` que abre o seletor
  multi de membros do quadro), **Etiquetas** (pills + `＋`), **Prazo** (badge /
  date picker), **Descrição** (editável ao clicar), **Anexos** (componente
  existente `CardAttachments`).
- Coluna direita: **Comentários** — thread (componente existente `CardComments`)
  + campo de escrever fixo embaixo.
- Responsivo: abaixo de um breakpoint vira coluna única, comentários no fim.
- **Novo componente** de seleção múltipla de responsáveis (lista só membros do
  quadro, checkbox/toggle, avatar + nome). Mesma pegada do seletor de etiquetas.

### `KanbanColumn.vue` (cabeçalho) — opção A aprovada

- Nome (editável, como hoje) + **contador** de cards (total da coluna) + botão
  `＋` que adiciona card no topo. Mantém o "+ Novo card" no rodapé e a lixeira.

### `BoardView.vue` (barra de topo) — opção B aprovada

- Filtros de responsável e etiqueta restilizados (combinar com o DS).
- Atalho **"Meus cards"**: toggle que filtra cards onde o usuário atual
  (`currentUser`) está em `assignee_ids`.
- Filtro de responsável casa quando o agente é **um dos** `assignee_ids`.

## Tempo real

Sem mudança de mecanismo: o `after_action :broadcast_board_update` existente já
rebroadcasta o quadro inteiro (com `account_id` no payload — ver
`cable-events-need-account-id`). Como os responsáveis passam a vir em
`assignee_ids` dentro do card, a atualização de responsáveis se propaga de graça.

## i18n

Chaves novas no overlay `fazer-ai/locale/<locale>/kanban.json` (en, pt_BR, es):
contador/`＋` da coluna, "Meus cards", rótulo "Responsáveis" (plural), rótulos do
seletor múltiplo. Sem editar locale do upstream.

## Testes

- **Backend (CI, sem Ruby local):** model `CardAssignee` + associações; validação
  de pertencimento (responsável fora dos membros → inválido/`422`); migration de
  backfill (card com `assignee_id` → vira `card_assignee`; idempotente); payload
  com `assignee_ids`; create/update com array de responsáveis.
- **Frontend:** render do card com pills + avatares + badge de prazo vencido;
  filtro "Meus cards" e filtro por responsável com múltiplos; seletor múltiplo de
  responsáveis restrito a membros.

## Arquivos

**Novos (nossos):** `app/models/custom/kanban/card_assignee.rb`; migration
`...add_card_assignees_to_kanban`; componente do seletor múltiplo de responsáveis
em `routes/dashboard/kanban/components/`.

**Editados (nossos, já marcados como custom):** `card.rb`, `_card.json.jbuilder`,
cards controller, `KanbanCard.vue`, `CardDialog.vue`, `KanbanColumn.vue`,
`BoardView.vue`, `dashboard/api/custom/kanban.js`,
`store/modules/custom/kanban.js`, `kanban.json` (3 locales).

**Upstream:** `db/schema.rb` (nova tabela + versão; remoção da coluna
`assignee_id` do kanban — tabela nossa, mas o schema é arquivo do upstream). Sem
novas edições em arquivos do upstream além do schema, que a feature já editava.

## Fora de escopo (YAGNI)

- Checklists, capa de card, datas de início (só prazo).
- Notificação ao ser atribuído (pode virar item futuro).
- Reordenar/arrastar colunas (mantém como está).
