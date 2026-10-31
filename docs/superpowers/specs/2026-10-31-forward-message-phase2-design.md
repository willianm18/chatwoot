# Encaminhar mensagem (WhatsApp nativo) — Fase 2: seleção múltipla

Data: 2026-10-31
Fork: willianm18/chatwoot (fazer.ai → chatwoot)
Backlog item: 3 (CLAUDE.md) — Fase 2

## Problema

A Fase 1 encaminha **uma** mensagem pelo menu de contexto. O backend (`Custom::Messages::ForwardService`
+ `forwards#create`) já aceita uma **lista** de `message_ids`, então falta a UI de seleção múltipla
estilo WhatsApp.

## Decisão de interação (fechada com o usuário)

- **WhatsApp puro (opção a):** "Encaminhar" no menu de contexto **sempre entra no modo de seleção**,
  com a mensagem clicada já marcada. Mesmo para encaminhar uma só, marca-se e confirma-se na barra.
- No modo seleção: **checkbox em cada bolha encaminhável**, clique na bolha alterna a seleção.
- **Barra de ação** com "N selecionadas", **Encaminhar** e **Cancelar** (também sai com `Esc`).
- Confirmar abre o **mesmo `ForwardWhatsappPanel`** (escolha de contato, já escopado à caixa) e envia
  os N `message_ids`. Ao concluir, limpa a seleção e sai do modo.

## Arquitetura

### Estado de seleção (novo, nosso)

`components-next/message/forward/useForwardSelection.js` — composable com estado reativo **compartilhado**
em escopo de módulo (estado efêmero de UI; sem Vuex):

- `active` (bool), `conversationId` (number|null), `ids` (reactive Set de message ids).
- `start(messageId, conversationId)` — ativa, fixa a conversa, marca a mensagem.
- `toggle(messageId)`, `isSelected(messageId)`, `count`.
- `clear()` — sai do modo e esvazia.
- `isActiveFor(conversationId)` — a UI só mostra checkbox/barra na conversa que iniciou a seleção.
  Trocar de conversa não arrasta a seleção.

### Critério "encaminhável" compartilhado (novo, nosso)

`components-next/message/forward/isForwardableMessage.js` — extrai a parte **por mensagem** do gate
(não privada, não reação, não falha/processando, não apagada, tem texto ou anexo). O gate do menu em
`Message.vue` passa a reusar este helper (mantendo os checks de **caixa** — WhatsApp de sessão — onde
estão). Os checkboxes das bolhas usam o mesmo helper. Uma fonte de verdade.

### UI

- **`Message.vue`** (upstream, edição mínima):
  - o handler do evento `forward` passa a chamar `start(messageId, conversationId)` do composable, em
    vez de abrir o painel;
  - quando `isActiveFor(conversationId)` e a mensagem é encaminhável, a bolha ganha um checkbox e o
    clique alterna a seleção (`toggle`);
  - o `ForwardWhatsappPanel` deixa de ser renderizado aqui (sobe para a conversa).
- **`ForwardSelectionBar.vue`** (novo, nosso): barra no nível da conversa com a contagem, Encaminhar,
  Cancelar; `Esc` cancela. Visível só quando `active`.
- **`ConversationView.vue`** (upstream, edição mínima): renderiza a `ForwardSelectionBar` e o
  `ForwardWhatsappPanel` (aberto pela barra).
- **`ForwardWhatsappPanel.vue`** (nosso): refatorado para receber `messageIds` + `conversationId` por
  **props** (em vez de `useMessageContext`). Preview mostra o conteúdo quando é uma mensagem, ou
  "N mensagens" quando são várias. Continua chamando a action `forwardMessages` com a lista.

### Fluxo

1. Menu de contexto → "Encaminhar" → `start(id, convId)`.
2. Bolhas encaminháveis mostram checkbox; usuário marca/desmarca; barra mostra a contagem.
3. "Encaminhar" na barra → abre o painel (contato escopado à caixa).
4. Escolhe o contato → `forwardMessages({ conversationId, messageIds: [...ids], targetContactId })`.
5. Sucesso → toast, `clear()`.

## Testes

- **Composable** (`useForwardSelection`): start/toggle/isSelected/count/clear; escopo por conversa
  (`isActiveFor`).
- **`isForwardableMessage`**: aceita texto/anexo; recusa privada/reação/falha/apagada.
- **`ForwardSelectionBar`**: mostra a contagem; Encaminhar emite/abre com os ids; Cancelar/`Esc` limpa.
- **`ForwardWhatsappPanel`** (refatorado): recebe `messageIds` por props e envia a lista; preview de 1 vs N.
- **`Message.vue`**: "Encaminhar" entra no modo seleção; checkbox aparece só na conversa ativa e só em
  bolha encaminhável.

## Fora de escopo

- Seletor de caixa de destino (continua: mesma caixa de origem).
- Rótulo visual "Encaminhada" na bolha.
- Encaminhar localização / contato compartilhado / outros tipos não-mídia.
- Limite de quantidade de mensagens por encaminhamento.
