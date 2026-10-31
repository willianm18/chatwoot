# Encaminhar mensagem (WhatsApp nativo) — Design

Data: 2026-10-31
Fork: willianm18/chatwoot (fazer.ai → chatwoot)
Backlog item: 3 (CLAUDE.md)

## Problema

Hoje não existe "Encaminhar mensagem" no dashboard. Já existiu via script, mas quebrou com a
mudança para o conector WhatsApp nativo (baileys-api da fazer.ai). Precisamos de um encaminhamento
que funcione pelo conector atual.

## Decisões de escopo (fechadas com o usuário)

- **Fluxo**: ação na mensagem → buscar um **contato** → abrir/criar a conversa dele e enviar a cópia.
- **Caixa de destino**: sempre a **mesma caixa WhatsApp nativa** da mensagem de origem (a Ágeis tem
  basicamente um número nativo). Sem seletor de caixa.
- **Tipos encaminháveis**: **texto + mídia** (imagem, documento, áudio, vídeo).
- **Marca "Encaminhada"**: tentativa best-effort; se o conector não aceitar a flag, apenas **reenvia o
  conteúdo** (como o backlog já previa para a Cloud API). Não bloqueia a entrega.
- **Fases**: Fase 1 encaminha **uma** mensagem pelo menu de contexto. Fase 2 (depois) adiciona o modo
  de seleção múltipla estilo WhatsApp. O backend já nasce aceitando uma **lista** de mensagens, então
  a Fase 2 é só a UI de seleção.
- **Pós-envio**: toast de confirmação; **sem** navegação automática para a conversa de destino (link
  "abrir conversa" dispensado por ora).

## Arquitetura

Reaproveita as peças existentes; não cria caminho de envio novo:

- `ContactInboxWithContactBuilder` / `ContactInboxBuilder` — resolvem/criam o `contact_inbox` do
  contato de destino na caixa WhatsApp (já normalizam telefone e geram o `source_id`).
- `ConversationBuilder` — acha ou cria a conversa do `contact_inbox`.
- `Messages::MessageBuilder` — cria a mensagem **outgoing** na conversa de destino; o pipeline normal
  de outgoing (`SendReplyJob` → `channel.send_message`) dispara o envio pelo conector.
- Anexos são copiados **reaproveitando o mesmo blob** do ActiveStorage (um blob pode ter vários
  anexos), sem reupload.

### Backend

**Serviço novo** `app/services/custom/messages/forward_service.rb` (arquivo nosso, namespace `custom`):

- Entradas: `conversation` (origem), `message_ids` (array), `target_contact_id`, `user`.
- Validações (falha cedo, no serviço):
  - Caixa de origem é WhatsApp nativa (`inbox.channel.session_provider?` ou `provider == 'baileys'`).
  - Cada mensagem pertence à conversa de origem e é encaminhável: não é `activity`, não está
    `deleted`, não é `is_reaction`, não é `private`, não é `isUnsupported`; tem `content` ou anexos
    copiáveis (fileType em image/audio/video/file).
  - `target_contact_id` existe na conta e tem telefone (para gerar o source_id WhatsApp).
- Passos:
  1. Resolve o `contact_inbox` do contato na **caixa de origem** via `ContactInboxWithContactBuilder`.
  2. Acha/cria a conversa via `ConversationBuilder`.
  3. Para cada `message_id` **na ordem original**: monta params e chama `Messages::MessageBuilder`
     com `content`, `attachments` = blobs da mensagem de origem, e
     `content_attributes: { forwarded: true }`. A criação da outgoing dispara o envio.
- Retorno: a conversa de destino (para o controller serializar o `display_id`).

**Endpoint novo**: `POST /api/v1/accounts/:account_id/conversations/:conversation_id/messages/forward`.

- Controller novo nosso: `app/controllers/custom/api/v1/accounts/conversations/forwards_controller.rb`
  (ou um `collection` em messages). Params: `message_ids: []`, `target_contact_id`.
- Autorização: mesma política de criar mensagem na conversa de origem (agente precisa poder ver a
  conversa de origem) + poder ver o contato de destino.
- Erros de validação → `422` reusando os erros existentes.
- Registro da rota em `config/routes.rb` (edição mínima dentro do bloco `resources :messages`) →
  registrar em "Mudanças nossas".

### Frontend

- **Componente novo** `app/javascript/dashboard/components-next/message/forward/ForwardWhatsappPanel.vue`
  (arquivo nosso): busca de contato (reusa `createContactSearcher` de `composeConversationHelper`),
  lista de resultados, preview enxuto do que será encaminhado (texto ou "📎 anexo"), botão Encaminhar.
- **Menu de contexto** `app/javascript/dashboard/modules/conversations/components/MessageContextMenu.vue`:
  +1 item "Encaminhar" que emite `forward`. Edição mínima (upstream) → "Mudanças nossas".
- **Message.vue** (`components-next/message/Message.vue`): entrada `forward` em
  `contextMenuEnabledOptions`, habilitada só quando a caixa é WhatsApp nativa e a mensagem é
  encaminhável; abre o `ForwardWhatsappPanel`. Edição mínima (upstream) → "Mudanças nossas".
- **Store**: action nova `forwardMessages` em `store/modules/conversations/actions.js` que chama o
  endpoint. Sucesso → `useAlert` de confirmação.

### Marca "Encaminhada" e i18n

- `content_attributes.forwarded = true` na cópia (registro interno; permite exibir rótulo no futuro
  sem novo backend).
- Best-effort da flag ao conector: só se confirmado que o bridge aceita; caso contrário, reenvio do
  conteúdo. Não bloqueia.
- i18n no overlay do fork, nos três idiomas (en, pt_BR, es):
  `app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/conversation.json` com as chaves do
  menu/painel (ex.: `FORWARD`, título do painel, placeholder de busca, mensagem de sucesso/erro).

## Testes

- **Backend** (`spec/services/custom/messages/forward_service_spec.rb`):
  - encaminha texto (cria outgoing na conversa de destino);
  - encaminha com anexo (blob reaproveitado, sem reupload);
  - cria conversa quando não existe; reusa quando já existe;
  - recusa mensagem não encaminhável (atividade/apagada/privada/reação);
  - recusa caixa de origem que não é WhatsApp nativa;
  - envia N mensagens preservando a ordem.
- **Controller** (`spec/controllers/.../forwards_controller_spec.rb`): happy path + 422 de validação +
  autorização.
- **Frontend**: spec do `ForwardWhatsappPanel` (busca + envio dispara a action) e do item de menu
  condicional.

## Fora de escopo (Fase 2+)

- Modo de seleção múltipla estilo WhatsApp (checkbox nas bolhas, cabeçalho de seleção, barra de ação).
- Seletor de caixa de destino (mais de um número nativo).
- Rótulo visual "Encaminhada" na bolha.
- Encaminhar localização / contato compartilhado / outros tipos não-mídia.
