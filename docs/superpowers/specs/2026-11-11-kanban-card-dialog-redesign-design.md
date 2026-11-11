# Kanban — redesign do diálogo do cartão (fase 5)

- **Data:** 2026-11-11
- **Status:** aprovado (mock validado), aguardando revisão da spec antes do plano

## Objetivo

Deixar o diálogo do cartão mais parecido com o Trello e resolver o que ficou
feio/confuso no teste do HML (`custom.21`): prazo em pill, scroll independente
entre cartão e comentários, placeholder do comentário mais visível, anexos
reformulados, botões Salvar/Excluir mais agradáveis, barra de ação "Adicionar"
(Etiqueta · Data · Anexo), e **UI de etiquetas** (hoje não dá pra criar nenhuma).
Checklist fica fora desta fase (recurso próprio depois).

## Decisões (do brainstorming + mock aprovado)

- **Etiquetas por quadro** (estilo Trello, já no backend), com UI de
  **criar/editar/excluir** no seletor — não reusar as labels de conversa.
- **Checklist adiado.**
- Mock aprovado: barra "Adicionar" no topo, prazo em pill, anexos com
  miniatura+nome+tamanho, comentário mais escuro, scroll separado, rodapé
  Salvar/Excluir.

## Backend (mínimo)

Quase tudo é frontend. Backend só:
- **`_card.json.jbuilder`** (anexos): adicionar `json.byte_size file.byte_size`
  para exibir o tamanho. (`filename`, `file_url`, `content_type`, `is_image` já
  existem.)
- **Etiquetas:** nenhum backend novo — a rota `custom/kanban/.../labels` já tem
  `create/update/destroy` e o `labels_controller` já implementa os três.

## Frontend

Tailwind only, tokens `n-*`. Arquivos nossos do Kanban.

### 1. API/store — `updateLabel`
- `dashboard/api/custom/kanban.js`: adicionar `updateLabel(boardId, id, data)` →
  `PATCH .../labels/:id` com `{ label: data }` (espelha `createLabel`).
- `store/modules/custom/kanban.js`: action `updateLabel` (refetch do board), ao
  lado de `createLabel`/`deleteLabel`.

### 2. Seletor de etiquetas com CRUD (`LabelPicker.vue` novo)
- Novo componente `routes/dashboard/kanban/components/LabelPicker.vue`: lista as
  etiquetas do quadro como toggles (marca/desmarca no cartão); cada uma com um
  lápis que abre edição inline (nome + paleta de 10 cores de `constants.js`) e um
  excluir; um "criar etiqueta" (nome + cor). Usa `kanban/createLabel`,
  `updateLabel`, `deleteLabel` e emite o toggle de `label_ids` como hoje.
- `CardDialog.vue`: a seção Etiquetas passa a abrir o `LabelPicker` num popover
  (como o `AssigneePicker`), em vez dos botões soltos atuais.

### 3. Prazo em pill (`CardDialog.vue`)
- Quando há `due_date`: mostra uma **pill** compacta (ícone + data formatada +
  `✕` pra limpar), vermelha só quando vencida (reusa `isOverdue` de
  `cardDateFormat.js`). Sem data: acessível pela barra de ação "Data" (abre o
  seletor nativo inline). Remove o `<input type=date>` ocupando a linha inteira.

### 4. Barra de ação "Adicionar" (`CardDialog.vue`)
- Logo abaixo do título, uma linha de botões: **Etiqueta** (abre o `LabelPicker`),
  **Data** (revela o seletor de data), **Anexo** (dispara o upload). Estilo chip
  (`bg-n-alpha-black2`), bem Trello. As seções abaixo continuam mostrando o
  conteúdo atual (responsáveis, etiquetas, prazo, descrição, anexos).

### 5. Anexos reformulados (`CardAttachments.vue`)
- Cada anexo: miniatura (imagem) ou ícone por tipo + nome + **tamanho**
  (`byte_size` formatado) + "Remover". Trocar o `<input type=file>` nativo
  ("Escolher arquivo") por um botão **"Adicionar anexo"** que dispara um input
  escondido. Visual com cards (`bg-n-alpha-black1`, borda `n-weak`).

### 6. Comentários (`CardComments.vue`)
- O campo "Escreva um comentário…" (placeholder quando inativo) fica **mais
  escuro/visível**: borda `n-strong`/fundo `bg-n-alpha-black2`, texto `n-slate-11`
  (não `n-slate-10`), pra o operador perceber que existe.

### 7. Scroll independente (`CardDialog.vue`)
- O corpo do diálogo passa a ter **altura fixa** (dentro do `max-h` do `Dialog`),
  e **cada coluna rola sozinha**: a do cartão (esquerda) com `overflow-y-auto` e a
  dos comentários (direita) também, com o composer fixo no topo da direita e a
  lista de comentários rolando abaixo. Hoje o diálogo inteiro rola junto.

### 8. Rodapé Salvar/Excluir (`CardDialog.vue`)
- Rodapé com borda-topo sutil: **Salvar** (botão `bg-n-brand`, peso médio) à
  direita; **Excluir cartão** à esquerda, discreto (ícone de lixeira + texto
  `n-ruby-11`), não um link solto.

## Tempo real
Sem mudança de mecanismo — etiqueta/anexo/comentário já passam pelo
`after_action :broadcast_board_update`. A nova info (`byte_size`) vem no payload.

## i18n
Chaves novas no overlay `fazer-ai/locale/<locale>/kanban.json` (en, pt_BR, es):
barra de ação (`ACTIONS.LABEL/DATE/ATTACHMENT`), gerenciar etiquetas
(`LABELS.NEW/EDIT/DELETE/NAME`), "Adicionar anexo". Reusa chaves existentes onde
possível.

## Testes
- **Backend (CI):** payload do anexo inclui `byte_size`.
- **Frontend:** `LabelPicker` cria/edita/exclui e faz toggle; prazo pill limpa a
  data; barra de ação abre os pickers; anexo mostra tamanho e o botão novo.
  (Scroll e cores são cosméticos — cobrir só a lógica nova.)

## Arquivos
**Novos (nossos):** `components/LabelPicker.vue`.
**Editados (nossos):** `CardDialog.vue`, `CardComments.vue`, `CardAttachments.vue`,
`api/custom/kanban.js`, `store/modules/custom/kanban.js`,
`_card.json.jbuilder` (byte_size), `kanban.json` (3 locais).
**Upstream:** nenhum (sem schema/rota nova).

## Fora de escopo (YAGNI)
- Checklist (fase própria).
- Reordenar anexos; capa de cartão; múltiplas datas (início + fim).
- Reusar labels de conversa da conta.
