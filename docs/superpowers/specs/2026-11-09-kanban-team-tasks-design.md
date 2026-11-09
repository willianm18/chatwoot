# Kanban nativo — Tarefas de equipe (estilo Trello)

- **Data:** 2026-11-09
- **Status:** aprovado para planejamento
- **Escopo:** recurso novo do fork (`willianm18/chatwoot`), construído do zero.

## Contexto e motivação

A versão atual expõe um item "Kanban" na barra lateral (ícone de colunas, rota
`kanban_view`) que hoje abre **apenas uma tela de paywall** (`app/javascript/dashboard/
routes/dashboard/kanban/Index.vue`) apontando para `https://fazer.ai/kanban`. O Kanban
funcional é um **recurso Pro da fazer.ai**, cujo código **não está neste repositório e
não pode ser reproduzido** (regra do `.claude/CLAUDE.md` / `AGENTS.md`). Além disso, o
Kanban Pro é orientado a **funil de conversas**, não ao caso de uso desejado.

O que a equipe (contabilidade Ágeis) quer é um **quadro estilo Trello** para **tarefas do
dia a dia da equipe** — cartões criados pelos próprios atendentes, atribuídos aos
**próprios usuários do Chatwoot**, com filtros, usando o **mesmo login** do Chatwoot.
Ferramentas externas (ex.: Plane) foram descartadas porque rodam como aplicação separada,
com **sistema de usuários próprio** (login único só em edição paga), sem integração com os
usuários/contatos do Chatwoot.

Decisão: **construir um Kanban nativo próprio**, do zero, como recurso do fork, mantendo o
merge com o upstream barato (arquivos novos com prefixo `custom`, edições mínimas e
registradas nos arquivos do upstream).

## Requisitos (V1)

Confirmados no brainstorming:

1. **Vários quadros**, criados pelos usuários (não um único quadro global).
2. **Controle de acesso por quadro** — modelo simples: o usuário **tem acesso ou não**.
   Quem tem acesso faz tudo; o **criador é o dono** e é quem gerencia a lista de acesso e
   pode apagar o quadro.
3. O **administrador do Chatwoot** (perfil `administrator` da conta) **vê todos os
   quadros** automaticamente, sem precisar ser adicionado.
4. **Cartão (V1):** título (obrigatório), descrição, **um** responsável (agente do
   Chatwoot, opcional), etiquetas coloridas (por quadro), prazo (opcional).
5. **Colunas** ordenáveis; cartões ordenáveis e movíveis entre colunas (drag-and-drop).
6. **Reaproveitar** o item/rota existente (`kanban_view`): trocar o conteúdo do paywall
   pela nossa tela, para não haver dois ícones de Kanban.
7. **Sem tempo real na V1** — a tela reflete as mudanças ao recarregar/reentrar no quadro.

### Fora de escopo (fase 2+)

- Atualização em tempo real (ActionCable / WebSocket).
- Checklist (sub-tarefas), comentários no cartão, anexos.
- Múltiplos responsáveis por cartão.
- Papéis/permissões granulares por quadro (observador/membro/admin).
- Vínculo de cartões com conversas/contatos do Chatwoot.
- Filtros avançados / busca global (a V1 tem filtro simples por responsável e etiqueta na
  própria view do quadro, ver Frontend).

## Arquitetura

### 1. Modelo de dados

Tabelas novas, todas nossas, com prefixo `custom_kanban_`. Cada quadro pertence a uma
`Account`. Migrations criadas com `rails g migration` (timestamp real) e **idempotentes**
(`unless table_exists?` / `unless column_exists?`).

- **`custom_kanban_boards`**
  - `account_id` (FK lógica → `accounts`, indexado)
  - `name` (string, obrigatório)
  - `created_by_id` (FK lógica → `users`; o dono)
  - timestamps
- **`custom_kanban_board_members`** (lista de acesso — modelo A)
  - `custom_kanban_board_id` (indexado)
  - `user_id`
  - índice único em `[custom_kanban_board_id, user_id]`
  - O dono é inserido como membro na criação do quadro.
- **`custom_kanban_columns`**
  - `custom_kanban_board_id` (indexado)
  - `name` (string, obrigatório)
  - `position` (integer) — ordenação dentro do quadro
- **`custom_kanban_cards`**
  - `custom_kanban_column_id` (indexado)
  - `title` (string, obrigatório)
  - `description` (text, opcional)
  - `assignee_id` (FK lógica → `users`, opcional)
  - `due_date` (date, opcional)
  - `position` (integer) — ordenação dentro da coluna
  - `created_by_id` (FK lógica → `users`)
- **`custom_kanban_labels`** (etiquetas por quadro)
  - `custom_kanban_board_id` (indexado)
  - `name` (string)
  - `color` (string — valor de uma paleta fixa no frontend)
- **`custom_kanban_card_labels`** (join cartão ↔ etiqueta)
  - `custom_kanban_card_id`, `custom_kanban_label_id`
  - índice único no par

**Associações / limpeza:** seguir a diretriz do `AGENTS.md` — preferir associações e
callbacks do Rails a foreign keys de banco. `dependent: :destroy` em cascata
(board → columns → cards; board → members; board → labels; card → card_labels).

Models em `app/models/custom/kanban/` (namespace `Custom::Kanban::Board`,
`Custom::Kanban::Column`, `Custom::Kanban::Card`, `Custom::Kanban::BoardMember`,
`Custom::Kanban::Label`, `Custom::Kanban::CardLabel`).

### 2. Permissões (modelo A)

Regra única, aplicada **no ponto de entrada compartilhado** (sem guardas repetidas nos
downstream):

- **Acessar/ver um quadro:** o usuário é **membro** do quadro **OU** é `administrator` da
  conta. Expresso como um escopo de model:
  `Custom::Kanban::Board.accessible_by(user)` (retorna uma ActiveRecord relation para o
  controller filtrar/ordenar). O dono é sempre membro, então cai na primeira condição.
- **Editar colunas e cartões:** qualquer um com acesso ao quadro.
- **Gerenciar membros e apagar o quadro:** somente o **dono** (`created_by_id == user.id`).
  (O administrador da conta **vê** todos os quadros, mas a gestão de membros/exclusão fica
  com o dono; se for desejável que o admin também possa apagar, ver "Decisões em aberto".)
- Controllers usam o escopo para o carregamento (um quadro fora do acesso resulta em
  **404**, não 403, para não revelar existência) e uma checagem explícita de "dono" nas
  ações de membro/exclusão (retornando **403** quando o usuário tem acesso mas não é dono).

### 3. Backend — API

Controllers em `app/controllers/api/v1/accounts/custom/kanban/`, herdando do
`Api::V1::Accounts::BaseController` (que já resolve `Current.account` e autenticação).
Rotas aninhadas na conta, dentro de um escopo `custom`:

```
resources :kanban_boards (custom/kanban) do
  resources :members   # add/remove acesso (só dono)
  resources :labels    # CRUD de etiquetas do quadro
  resources :columns do
    # reorder de colunas
  end
  resources :cards do
    patch :move, on: :member   # mover cartão: column_id + position
  end
end
```

- **Mover cartão** (`PATCH .../cards/:id/move`) recebe `column_id` e `position` e recalcula
  as posições da coluna de origem e destino em Ruby/ActiveRecord (sem SQL cru).
- **Reordenar colunas** por um endpoint análogo ou um PATCH em lote no quadro.
- Validação de parâmetros no boundary do controller, reusando os erros existentes para
  retornar **422** em entrada inválida.
- Serialização via **jbuilder** nosso em `app/views/api/v1/accounts/custom/kanban/`.

### 4. Frontend

- **Rota reaproveitada:** `kanban_view` continua o mesmo nome/ícone/entrada de sidebar. O
  `kanban/Index.vue` deixa de ser o paywall e passa a ser a **lista de quadros** que o
  usuário acessa + botão "Novo quadro". (Se precisar de sub-rota para o quadro aberto,
  adicionar `kanban_board` com `:boardId` em `kanban.routes.js`.)
- **BoardView** (`kanban/BoardView.vue`) — colunas e cartões, **drag-and-drop com
  `vuedraggable`** (já é dependência do projeto; usado em Macros, ReorderableMultiSelect
  etc.). Arrastar cartão entre colunas chama o endpoint `move`.
- **Modal de cartão** — título, descrição, responsável (combobox de agentes da conta,
  reusando o componente/estado de agentes já existente), etiquetas (seleção múltipla da
  paleta do quadro), prazo (date picker existente).
- **Filtro simples na view do quadro (V1):** por responsável e por etiqueta (client-side,
  sobre os cartões já carregados) — atende o "filtros" do pedido sem endpoint de busca.
- **Gestão de acesso** — painel/modal no quadro (visível só ao dono) para adicionar/remover
  membros a partir da lista de agentes da conta.
- **Store Vuex** nossa (`dashboard/store/modules/custom/kanban/…`) + **API client**
  (`dashboard/api/custom/kanban.js`). Tudo em arquivos novos com prefixo custom.
- Estilo **somente Tailwind** (sem CSS custom/scoped), usando os tokens do design system
  (`n-*`), conforme `AGENTS.md`.

### 5. i18n

- Strings em `app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/kanban.json`
  (**en, pt_BR, es** — todas as três, toda chave presente nas três). O arquivo já existe
  (hoje com as chaves do paywall `KANBAN.PAYWALL.*`). Adicionar as chaves da nossa UI; as
  de paywall que deixarem de ser usadas podem ser removidas no mesmo PR.
- Nenhuma string nova em árvore de locale do upstream.

### 6. Edições em arquivos do upstream (registrar em "Mudanças nossas")

Mínimas:

- `app/javascript/dashboard/routes/dashboard/kanban/Index.vue` — passa de paywall para a
  lista de quadros nossa.
- `app/javascript/dashboard/routes/dashboard/kanban/kanban.routes.js` — se necessário,
  sub-rota do quadro aberto.
- `config/routes.rb` — bloco de rotas da API do Kanban (escopo `custom`).
- (Item do sidebar e ícone **já existem** — sem edição nova lá.)

Todo o resto é **arquivo novo** sob namespaces `custom`.

## Tratamento de erros

- Quadro/coluna/cartão inexistente ou fora do acesso do usuário → **404**.
- Usuário com acesso mas sem direito (ex.: não-dono tentando gerenciar membros/apagar
  quadro) → **403**.
- Parâmetros inválidos (ex.: título vazio, `position`/`column_id` ausente no move) →
  **422**, reusando os erros existentes no boundary do controller.
- Responsável/membro que não é agente da conta → rejeitado no boundary (**422**).

## Testes

- **Model specs:** escopo `accessible_by` (membro vê, não-membro não vê, admin vê tudo);
  cascata de `dependent: :destroy`; cálculo de `position`.
- **Request specs:** CRUD de board/column/card/label/member; `move` recalculando posições;
  regras de permissão (membro vê, não-membro → 404, não-dono → 403 em member/destroy, admin
  vê todos).
- **Frontend:** spec do store (mover cartão atualiza posições/coluna localmente) e da
  BoardView (render de colunas/cartões, filtro client-side por responsável/etiqueta).
- Seguir as diretrizes de spec do `AGENTS.md` (sem specs que só reafirmam a implementação).

## Decisões em aberto

1. O **administrador da conta** apenas **vê** todos os quadros; a gestão de membros e a
   exclusão continuam só com o **dono**. Se for desejável que o admin também gerencie/apague
   qualquer quadro, ajustar a checagem de "dono" para "dono OU administrador". (Default
   proposto: só o dono gerencia/apaga.)
2. Colunas padrão ao criar um quadro: criar automaticamente "A fazer / Fazendo / Feito" ou
   começar vazio. (Default proposto: criar as três, editáveis.)
