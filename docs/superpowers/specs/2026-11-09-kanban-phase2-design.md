# Kanban Fase 2 — tempo real, comentários e anexos

- **Data:** 2026-11-09
- **Status:** aprovado para planejamento
- **Depende de:** Fase 1 (`2026-11-09-kanban-team-tasks-design.md`), já em produção/HML (`v4.19.0-fazer-ai.141-custom.8`).

## Contexto

A Fase 1 entregou o Kanban nativo (quadros, colunas, cartões com responsável/etiquetas/prazo,
drag-and-drop, filtros, membros), **sem tempo real**. Esta fase adiciona três melhorias de colaboração
escolhidas pelo usuário, deixando checklist, múltiplos responsáveis, permissões granulares, vínculo com
conversa e busca avançada para depois:

1. **Tempo real** — quem está com um quadro aberto vê as mudanças dos outros na hora.
2. **Comentários** no cartão (texto puro).
3. **Anexos** no cartão (arquivos).

## Requisitos

- **Tempo real:** ao alterar o quadro (cartão/coluna/comentário/anexo/etiqueta — criar/editar/apagar/mover),
  os demais membros que estão vendo aquele quadro recarregam-no automaticamente. Abordagem **evento leve →
  refetch** (sem payloads granulares): os quadros são pequenos e já há refetch da Fase 1.
- **Comentários (simples):** texto puro, com autor e data/hora. Qualquer membro comenta; cada um edita/apaga
  os **próprios** comentários; o **dono do quadro** apaga qualquer um. Sem menções, markdown ou reações.
- **Anexos (simples):** **vários** arquivos por cartão (imagens e documentos) via ActiveStorage. Qualquer
  membro anexa; quem anexou (ou o dono) remove. Limite de **40 MB** por arquivo. Lista com nome/ícone e link
  de download; imagens exibem miniatura.

### Fora de escopo
Checklist, múltiplos responsáveis, permissões granulares, vínculo cartão↔conversa, busca global, menções,
markdown, reações, notificações por e-mail/push de comentários.

## Arquitetura

### 1. Modelo de dados
- **`custom_kanban_card_comments`** (migration idempotente): `custom_kanban_card_id` (indexado), `user_id`
  (autor), `content` (text, obrigatório), timestamps. Model `Custom::Kanban::CardComment`
  (`belongs_to :card`, `belongs_to :user`, `validates :content, presence: true`).
- No `Custom::Kanban::Card`: `has_many :comments` (`dependent: :destroy`) e **`has_many_attached :files`**
  (ActiveStorage). Validação de tamanho (40 MB) espelhando o padrão do Chatwoot (ver `app/models/attachment.rb`
  / macros). Sem tabela nova para anexos.

### 2. Backend — API (arquivos novos; rotas aninhadas no `custom/kanban`)
Rotas novas em `config/routes.rb`, dentro do bloco `cards` já existente:
```ruby
resources :cards, only: [:create, :update, :destroy] do
  patch :move, on: :member
  resources :comments, only: [:create, :update, :destroy]      # NOVO
  resources :attachments, only: [:create, :destroy]            # NOVO
end
```
- **CommentsController** (herda do `Custom::Kanban::BaseController`): `create` (qualquer membro),
  `update`/`destroy` (autor **ou** dono do quadro → senão **403**). `set_card` reusa o escopo por quadro da
  Fase 1 (cartão fora do quadro → 404).
- **AttachmentsController**: `create` (multipart, `params[:file]`), `destroy` por `attachment_id`
  (quem anexou — rastreado por `blob.metadata['uploaded_by']` — ou dono → senão 403). Rejeita arquivo > 40 MB
  no boundary (**422**).
- **Payload do cartão** (`_card.json.jbuilder`) passa a incluir:
  - `comments`: `[{ id, author_id, author_name, content, created_at }]`
  - `attachments`: `[{ id, filename, file_url, content_type, is_image }]` (url via `url_for`/`rails_blob_url`
    no padrão do projeto).

### 3. Tempo real
- **Ponto único de disparo:** `after_action` no `Api::V1::Accounts::Custom::Kanban::BaseController`, nas ações
  que alteram o quadro (columns/cards/comments/attachments/labels — create/update/destroy/move/reorder). Um
  broadcast **por request** (evita tempestade no `move`, que resequencia vários cartões). O `BoardsController`
  (não aninhado) fica de fora — mudanças na lista de quadros não precisam de tempo real (YAGNI).
- **Broadcast:** `ActionCableBroadcastJob.perform_later(tokens, 'kanban.board.updated', { board_id: id })`,
  onde `tokens = board.member_users.pluck(:pubsub_token)` (User tem `pubsub_token` via `Pubsubable`).
  Reusa o job existente — nada novo no backend de cable.
- **Frontend:** adiciona `'kanban.board.updated'` ao mapa `events` de
  `app/javascript/dashboard/helper/actionCable.js` (edição mínima no upstream, registrada). O handler despacha
  uma action nova `kanban/onBoardUpdated(boardId)` que, **se o quadro atualmente aberto for esse**, refaz o
  `fetchBoard`. Um cartão aberto no `CardDialog` **não** é sobrescrito no meio de uma edição — comentários/
  anexos novos de terceiros aparecem ao reabrir o cartão (o refetch atualiza as colunas/cartões por baixo).

### 4. Frontend — UI
- **`CardDialog.vue`** ganha, abaixo dos campos atuais, duas seções (só quando editando um cartão existente —
  cartão novo salva primeiro):
  - **Comentários:** lista (autor, data relativa, texto) + caixa para novo comentário; editar/excluir nos
    próprios (e dono). Componente novo `components/CardComments.vue`.
  - **Anexos:** input de arquivo (múltiplo) + lista com ícone/miniatura, nome e botão remover. Componente novo
    `components/CardAttachments.vue`.
- **Store** (`store/modules/custom/kanban.js`): actions novas `createComment`, `updateComment`,
  `deleteComment`, `addAttachment`, `removeAttachment` (todas refazem `fetchBoard` após a escrita, como na
  Fase 1) e `onBoardUpdated(boardId)` (refetch condicional ao quadro aberto). API client
  (`api/custom/kanban.js`) ganha os métodos correspondentes (o de anexo envia `FormData`).
- Estilo só Tailwind / tokens `n-*`.

### 5. i18n e edições no upstream
- Chaves novas em `fazer-ai/locale/<locale>/kanban.json` (en, pt_BR, es): `KANBAN.COMMENTS.*` (placeholder,
  enviar, editar, excluir, vazio) e `KANBAN.ATTACHMENTS.*` (anexar, remover, vazio, muito grande).
- Edições mínimas no upstream a registrar em "Mudanças nossas": `config/routes.rb` (comments/attachments) e
  `app/javascript/dashboard/helper/actionCable.js` (uma linha no mapa `events` + um handler curto).

### 6. Tratamento de erros
- Comentário/anexo em cartão fora do acesso do usuário → **404** (reusa o escopo do `BaseController`).
- Editar/apagar comentário de outro (não-autor, não-dono) → **403**. Remover anexo sem direito → **403**.
- Arquivo > 40 MB ou `content` vazio → **422**.

### 7. Testes
- **Model:** `CardComment` (validação de presença; cascata do card). Card: anexo rejeita > 40 MB.
- **Request specs:** comments create/update/destroy com regras de autor/dono (403); attachments create/destroy
  (403 sem direito, 422 > 40 MB); card show inclui comments/attachments.
- **Tempo real:** spec de que uma ação mutante enfileira `ActionCableBroadcastJob` com `kanban.board.updated`
  e os tokens dos membros (e **não** para não-membros).
- **Frontend:** store (`onBoardUpdated` só refaz fetch quando o board aberto é o do evento; `createComment`
  refaz fetch); specs leves dos componentes de comentários/anexos.

## Decisões em aberto
1. **Admin que vê um quadro sem ser membro não recebe tempo real** (broadcast só para membros). Aceitável:
   ele recarrega manualmente. (Default: broadcast só para membros.)
2. **Rastreio de "quem anexou"** via `blob.metadata['uploaded_by']` (gravado no upload). Se preferir não
   depender de metadata do blob, cair para "só o dono remove". (Default: metadata + dono.)
