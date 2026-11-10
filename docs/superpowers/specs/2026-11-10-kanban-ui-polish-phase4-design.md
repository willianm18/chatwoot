# Kanban — polish de UI (fase 4): cor por coluna, filtros compactos, editor rico com imagem

- **Data:** 2026-11-10
- **Status:** aprovado, aguardando revisão da spec antes do plano

## Objetivo

Três melhorias de UI no Kanban nativo, sobre a Fase 3 já no HML (`custom.17`):
1. **Cor por coluna** — cada coluna recebe uma cor opcional da paleta fixa (a mesma
   da "cor por caixa"), aplicada como faixa tingida no cabeçalho da coluna.
2. **Filtros compactos** — trocar os dois `<select>` largos empilhados por controles
   compactos inline no cabeçalho do quadro.
3. **Editor rico com imagem inline** — descrição e comentários viram editor rico
   (ProseMirror) com colar/upload de imagem embutida no texto.

Nenhuma tabela nova; só uma coluna nova (`custom_kanban_columns.custom_color`).

## Decisões (do brainstorming)

- Cor **por coluna** (não por quadro), reusando a paleta de 10 cores
  `INBOX_COLOR_PALETTE`/`Custom::InboxCustomColor::PALETTE`.
- Aplicação: **faixa colorida no cabeçalho inteiro** da coluna (não barra fina).
- Editável por **qualquer membro** do quadro (igual a renomear/excluir coluna).
- Filtros: **barra compacta inline** (título + Responsável ▾ + Etiqueta ▾ + toggle
  "Meus cards" + "Membros"), não um botão-popover.
- Imagem no texto: **embutida no fluxo** (editor rico), na descrição **e** nos
  comentários; colar (Ctrl+V) **e** botão de upload.

## 1. Cor por coluna

### Backend
- **Migration idempotente** `...add_custom_color_to_kanban_columns`: adiciona
  `custom_color` (string, nullable) a `custom_kanban_columns`
  (`unless column_exists?`). `db/schema.rb` editado à mão (nova versão) — dev com
  Ruby confere o schema regenerado.
- **Model `Custom::Kanban::Column`:** `validates :custom_color, inclusion: { in:
  Custom::InboxCustomColor::PALETTE }, allow_nil: true` (reusa a paleta do backend,
  sem 3ª cópia).
- **`columns_controller`:** `column_params` passa a permitir `:custom_color`.
- **`_column.json.jbuilder`:** `json.custom_color column.custom_color`.

### Frontend
- **`KanbanColumn.vue`:** o cabeçalho ganha a faixa tingida quando
  `column.custom_color` está presente (fundo = mistura da cor com o fundo da
  coluna; texto claro). Sem cor → cabeçalho atual.
- **Seletor de cor:** um botãozinho no cabeçalho (ícone de paleta) abre um popover
  com as 10 bolinhas (`INBOX_COLOR_PALETTE`) + "sem cor"; ao escolher,
  `kanban/updateColumn` com `custom_color`. Reaproveita o padrão de
  `components/custom/InboxColorPicker.vue` (componente novo nosso
  `KanbanColumnColorPicker.vue` se o do inbox não encaixar direto).

## 2. Filtros compactos

Só frontend, em `BoardView.vue`. O cabeçalho vira uma linha única: título do
quadro + controles compactos:
- **Responsável** e **Etiqueta** — dropdowns compactos estilizados (não o `<select>`
  largo nativo). Mantêm a lógica atual (`assigneeFilter`/`labelFilter` sobre
  `members`/`labels`).
- **"Meus cards"** — toggle compacto (já existe).
- **"Membros"** — ao fim (`ms-auto`), só para o dono (já existe).
- **Limpar** aparece quando há filtro ativo.

Sem mudança de backend nem de lógica de filtragem; só layout/estilo (tokens `n-*`,
Tailwind). Pode-se extrair um pequeno `KanbanFilterSelect.vue` para o dropdown
compacto se reduzir repetição.

## 3. Editor rico com imagem inline

### Reuso (sem backend novo)
- **Entrada:** `components-next/Editor/Editor.vue` (envolve `WootWriter/Editor.vue`
  ProseMirror). Já trata colar imagem (`INLINE_IMAGE_PASTE_TYPES`) e botão de
  upload (`openFileBrowser` → `uploadImageToStorage` → `uploadFile` →
  `/api/v1/accounts/:accountId/upload` → insere `![](fileUrl)` inline). Config
  enxuta: `enableCannedResponses=false`, `enableVariables=false`,
  `enableCaptainTools=false`, sem assinatura.
- **Exibição:** markdown renderizado pelo `shared/helpers/MessageFormatter`
  (MarkdownIt) → HTML com as imagens. Reusar via `useMessageFormatter`.
- **Armazenamento:** `description` e `content` (ambos `text`) passam a guardar
  **markdown**. Sem migration; texto puro antigo é markdown válido (retrocompatível).

### Descrição (`CardDialog.vue`)
- O `textarea` da descrição vira o `Editor` (markdown em `form.description`). O
  editor já mostra formatação e imagens enquanto edita (WYSIWYG), então não precisa
  de render separado no diálogo.

### Comentários (`CardComments.vue`)
- **Input:** o `<input>` vira o `Editor` compacto (cresce ao focar) + botão Enviar.
  Envia markdown em `content`.
- **Exibição:** cada comentário existente passa a renderizar o markdown via
  `MessageFormatter` (`v-html` do HTML sanitizado que o formatter devolve), para
  mostrar imagens e formatação. Hoje é `whitespace-pre-wrap` texto puro.

### Observações
- `accountId` para o `uploadFile`: obter do getter de conta atual
  (`getCurrentAccountId`/route param), como o resto do dashboard.
- Limite de imagem inline do editor: 4 MB (constante do WootEditor) — manter.
- Imagens do editor são blobs soltos referenciados por URL (padrão do editor de
  artigos do Chatwoot); não são anexos do cartão. Os **anexos do cartão**
  (`CardAttachments`) continuam como estão.

## Tempo real
Sem mudança: edições de coluna (cor), descrição e comentários já passam pelo
`after_action :broadcast_board_update` e re-fetch. A cor nova vem no payload da
coluna; a descrição/comentário em markdown no payload do cartão.

## i18n
Chaves novas no overlay `fazer-ai/locale/<locale>/kanban.json` (en, pt_BR, es):
rótulo do seletor de cor da coluna ("Cor da coluna" / "Sem cor"). Filtros e editor
reusam chaves existentes (placeholders dos filtros, `COMMENTS.*`).

## Testes
- **Backend (CI):** validação de `custom_color` na `Column` (aceita cor da paleta,
  rejeita fora dela, aceita nil); `columns_controller` grava `custom_color`;
  payload traz `custom_color`.
- **Frontend:** `KanbanColumn` renderiza a faixa tingida quando há `custom_color`;
  seletor emite `updateColumn`. (Editor/MessageFormatter são componentes do
  upstream já testados; cobrir só a fiação nossa se não for trivial.)

## Arquivos
**Novos (nossos):** migration `...add_custom_color_to_kanban_columns`;
`components/custom/KanbanColumnColorPicker.vue` (se necessário); possível
`KanbanFilterSelect.vue`.
**Editados (nossos):** `models/custom/kanban/column.rb`, `columns_controller.rb`,
`_column.json.jbuilder`, `KanbanColumn.vue`, `BoardView.vue`, `CardDialog.vue`,
`CardComments.vue`, `kanban.json` (3 locais).
**Upstream:** `db/schema.rb` (coluna nova + versão).

## Fora de escopo (YAGNI)
- Cor por quadro (só por coluna).
- Editor rico no título do cartão (continua input simples).
- Galeria/lightbox de imagens (o markdown abre a imagem no link; sem visualizador
  dedicado nesta fase).
- Vincular as imagens do editor como anexos do cartão.
