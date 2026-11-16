# Arquivar conversas — design

Data: 2026-11-16

## Objetivo

Permitir que o agente **arquive** uma conversa para tirá-la do fluxo de atendimento sem
resolvê-la. Casos de uso: parar algo que vai demandar tempo para retomar depois, tirar
lixo da frente, e juntar os grupos num canto consultável.

Uma conversa arquivada some das listas normais (Minhas / Não atribuídas / Todos) e só
aparece numa nova aba **Arquivadas**. O arquivamento é **compartilhado pela conta**
(estado único na conversa) e **independente do status**: uma arquivada **não reabre** nem
volta para as listas normais quando chega mensagem nova — fica lá até alguém desarquivar.

### Fora de escopo

- Arquivamento pessoal (por agente). É compartilhado.
- Contador de arquivadas na aba (YAGNI na V1).
- Auto-arquivar por regra/automação. É sempre ação manual.

## Comportamento

- **Arquivar** marca a conversa como arquivada para toda a conta.
- Arquivada some de Minhas/Não atribuídas/Todos e aparece só em **Arquivadas** (lista plana,
  sem subdivisão por assignee).
- Mensagem nova numa arquivada **não** a desarquiva, **não** a traz de volta às listas
  normais e **não** conta como não lida ali (ela nem aparece nessas abas).
- **Desarquivar** devolve a conversa ao fluxo normal mantendo o status que ela já tinha
  (aberta continua aberta; resolvida continua resolvida).
- O flag não liga para o tipo de conversa: grupos arquivam igual às conversas 1:1.
- Em tempo real: arquivar/desarquivar dispara o broadcast de atualização da conversa já
  existente; os outros clientes removem/adicionam a conversa da lista sem recarregar.

## Armazenamento (decisão)

**Coluna booleana `custom_archived` na `conversations`** (default `false`, `null: false`),
com índice parcial (`where custom_archived = true`). Estado único por conversa, compartilhado.

Alternativas descartadas:
- **Etiqueta "arquivada"**: suja a UI de etiquetas, qualquer um adiciona/remove como
  etiqueta normal, e "esconder essa etiqueta de todas as listas normais" fica gambiarra e
  lenta.
- **Novo valor de status `archived`**: o enum de status está em todo lugar (reabertura por
  mensagem, relatórios, SLA, automações, state machine). Muita edição no upstream e
  arriscado para o merge com a fazer.ai.

## Backend

### Migration

`add_custom_archived_to_conversations` (idempotente):
- `custom_archived boolean default false not null` na `conversations`.
- Índice parcial `where custom_archived = true`.
- `db/schema.rb` atualizado (sem Ruby local; **um dev com Ruby roda
  `bundle exec rails db:migrate` e confere que o schema regenerado é idêntico** antes do
  merge).

### `ConversationFinder` (edição mínima no upstream)

No `set_up`, uma chamada `filter_by_archived` + o método:

```ruby
def filter_by_archived
  archived = ActiveModel::Type::Boolean.new.cast(params[:archived])
  @conversations = @conversations.where(custom_archived: archived)
end
```

- Sem `params[:archived]` (ou `false`): filtra `custom_archived: false` → arquivadas somem
  das abas normais, e os contadores mine/unassigned/all já as ignoram de graça (são
  calculados sobre `@conversations` depois do `set_up`).
- `params[:archived]=true`: só as arquivadas.

Registrar em "Mudanças nossas" (`.claude/CLAUDE.md`).

### Ação arquivar/desarquivar (arquivos novos nossos)

Padrão do "Encaminhar mensagem": controller nosso aninhado na conversa.

- Rota em `config/routes.rb` (única edição upstream aqui), no bloco
  `scope module: :conversations`:
  `post :custom_archive` e `post :custom_unarchive` como `member`, ou um controller
  `custom_archives` com `create`/`destroy`. (Decidir no plano; preferir o par explícito pela
  clareza da UI.)
- Controller novo `Api::V1::Accounts::Conversations::...` que seta `custom_archived` e salva.
  O `after_update`/broadcast de conversa já existente propaga o `conversation.updated`.

### Payload

`json.custom_archived` no jbuilder/presenter da conversa (lista e show), para o front saber o
estado e filtrar em tempo real.

## Frontend

### Aba "Arquivadas"

- 4ª aba na mesma linha de Minhas / Não atribuídas / Todos, em `ChatList.vue` (ao lado das
  `assigneeTabItems` / `wootConstants.ASSIGNEE_TYPE`).
- Como "arquivadas" é ortogonal a assignee, é um valor de aba especial: quando ativa, manda
  `archived=true` no fetch e **ignora** o filtro de assignee → lista plana de todas as
  arquivadas da conta.
- i18n da aba no overlay.

### Store

- As listas normais escondem conversas com `custom_archived = true`; a aba Arquivadas mostra
  só essas.
- Reage ao evento de atualização da conversa (cable): arquivou numa aba → some das outras e
  aparece em Arquivadas sem recarregar.

### Ação "Arquivar" / "Desarquivar"

Em dois lugares, chamando a action da store → API:
- **Menu de contexto do card** na lista (`ConversationCard` / `MoreActions`): "Arquivar" nas
  abas normais, "Desarquivar" dentro de Arquivadas.
- **Cabeçalho da conversa aberta** (`ConversationHeader`), ao lado de Resolver.

### i18n

Chaves `ARCHIVE.*` (aba, ações arquivar/desarquivar) em en / pt_BR / es, em arquivo nosso no
overlay (`fazer-ai/locale/<locale>/...`).

## Testes

- **Finder** (`spec/finders/conversation_finder_spec.rb` ou spec nosso): abas normais
  excluem arquivadas; contadores mine/unassigned/all ignoram arquivadas; `archived=true`
  retorna só as arquivadas.
- **Controller**: arquivar seta o flag e dispara o broadcast; desarquivar limpa o flag;
  conversa arquivada mantém o status.
- **Store (front)**: a conversa arquivada sai das listas normais e entra em Arquivadas ao
  receber o evento de atualização.

## Arquivos (resumo)

Upstream (edição mínima, registrar em "Mudanças nossas"):
- `db/schema.rb` — coluna + versão da migration.
- `app/finders/conversation_finder.rb` — `filter_by_archived`.
- `config/routes.rb` — rota de arquivar/desarquivar.
- `app/views/api/v1/.../_conversation.json.jbuilder` (ou presenter) — `custom_archived`.
- `app/javascript/dashboard/components/ChatList.vue` — 4ª aba.
- `ConversationCard` / `MoreActions` e `ConversationHeader` — ação arquivar/desarquivar.
- store de conversas — filtro + action.

Novos (nossos):
- migration `...add_custom_archived_to_conversations`.
- controller de arquivar/desarquivar.
- i18n `ARCHIVE.*` no overlay (en/pt_BR/es).

Reverter = tirar a aba/ação/filtro/rota/param, dropar a coluna.
