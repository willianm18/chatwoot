# Encaminhar mensagem (WhatsApp nativo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar "Encaminhar mensagem" numa conversa WhatsApp nativa — escolher um contato e reenviar a cópia (texto + mídia) pelo conector atual.

**Architecture:** Serviço novo `Custom::Messages::ForwardService` resolve o contact_inbox/conversa do contato na mesma caixa e cria uma outgoing por mensagem via `Messages::MessageBuilder` (o pipeline normal de outgoing envia). Endpoint novo + item no menu de contexto + painel de busca de contato. Anexos reaproveitam o blob do ActiveStorage.

**Tech Stack:** Rails 7 (services/controllers/RSpec), Vue 3 `<script setup>` (components-next), Vuex, vitest.

## Global Constraints

- Responder ao usuário em pt-BR; código/comentários/commits em inglês.
- Arquivos novos com namespace/prefixo `custom`. Edição em arquivo do upstream só se inevitável e registrada em "Mudanças nossas" no `.claude/CLAUDE.md`.
- Traduções do fork SEMPRE em en, pt_BR e es, nos overlays `fazer-ai/locale/<locale>/` — nunca no tree do upstream.
- Caixa de origem precisa ser WhatsApp de sessão (baileys/native/zapi/uazapi): `inbox.channel.session_provider? || provider == 'baileys'`. Front: `SESSION_PROVIDERS` de `helper/whatsappSession.js`.
- Não commitar no `main`; trabalhar na branch `feat/forward-message-whatsapp`.
- Cada feature com spec (backend + frontend).

---

### Task 1: Backend — `Custom::Messages::ForwardService`

**Files:**
- Create: `app/services/custom/messages/forward_service.rb`
- Test: `spec/services/custom/messages/forward_service_spec.rb`

**Interfaces:**
- Produces: `Custom::Messages::ForwardService.new(conversation:, message_ids:, target_contact:, user:).perform` → retorna a `Conversation` de destino. Levanta `CustomExceptions::...`/`ArgumentError` nas validações.

- [ ] **Step 1: Write failing spec** cobrindo: encaminha texto (cria 1 outgoing na conversa de destino do contato na mesma caixa); encaminha com anexo (blob reaproveitado — `new_attachment.blob == source_attachment.blob`); reusa conversa existente; recusa caixa de origem não-session (levanta erro); recusa mensagem apagada/privada/reação/atividade; envia 2 mensagens na ordem (`content` das outgoings na ordem dos `message_ids`). Usar factories `create(:channel_whatsapp, provider: 'baileys', sync_templates: false, validate_provider_config: false)`, `create(:conversation)`, `create(:message)`, `create(:contact, phone_number: '+5511999990000')`.

- [ ] **Step 2: Run, expect fail (service undefined).**
Run: `bundle exec rspec spec/services/custom/messages/forward_service_spec.rb`
Expected: FAIL (uninitialized constant Custom::Messages::ForwardService)

- [ ] **Step 3: Implement the service.**

```ruby
module Custom
  module Messages
    class ForwardService
      pattr_initialize [:conversation!, :message_ids!, :target_contact!, :user!]

      FORWARDABLE_FILE_TYPES = %w[image audio video file].freeze

      def perform
        validate_source_inbox!
        messages = load_forwardable_messages!
        target_conversation = resolve_target_conversation!
        messages.each { |message| forward(message, target_conversation) }
        target_conversation
      end

      private

      def source_inbox
        @source_inbox ||= conversation.inbox
      end

      def validate_source_inbox!
        channel = source_inbox.channel
        unless channel.is_a?(Channel::Whatsapp) && (channel.session_provider? || channel.provider == 'baileys')
          raise ArgumentError, 'Forwarding is only available on native WhatsApp inboxes'
        end
      end

      # Keeps the order the caller listed, and refuses the whole request if any id is not
      # forwardable — a partial forward is worse than an error the agent can act on.
      def load_forwardable_messages!
        messages = conversation.messages.where(id: message_ids).index_by(&:id)
        message_ids.map do |id|
          message = messages[id.to_i] || messages[id]
          raise ArgumentError, "Message #{id} is not in this conversation" if message.blank?
          raise ArgumentError, "Message #{id} cannot be forwarded" unless forwardable?(message)

          message
        end
      end

      def forwardable?(message)
        return false if message.private?
        return false if message.reaction?
        return false if message.content_attributes['deleted']
        return false if message.content_attributes['is_unsupported']
        return false unless message.incoming? || message.outgoing?

        message.content.present? || copyable_attachments(message).any?
      end

      def copyable_attachments(message)
        message.attachments.select { |a| FORWARDABLE_FILE_TYPES.include?(a.file_type) }
      end

      def resolve_target_conversation!
        contact_inbox = ::ContactInboxWithContactBuilder.new(
          inbox: source_inbox,
          contact_attributes: {
            name: target_contact.name,
            phone_number: target_contact.phone_number,
            identifier: target_contact.identifier,
            email: target_contact.email
          }.compact
        ).perform
        raise ArgumentError, 'Could not resolve a WhatsApp contact for the target' if contact_inbox.blank?

        ::ConversationBuilder.new(params: {}, contact_inbox: contact_inbox).perform
      end

      def forward(message, target_conversation)
        ::Messages::MessageBuilder.new(user, target_conversation, build_params(message)).perform
      end

      def build_params(message)
        {
          message_type: 'outgoing',
          content: message.content,
          attachments: copyable_attachments(message).map { |a| a.file.blob },
          content_attributes: { forwarded: true }
        }.with_indifferent_access
      end
    end
  end
end
```

- [ ] **Step 4: Run spec, expect pass.** Ajustar factories/asserts conforme a realidade (ex.: `source_id` do contact_inbox, `provider_config`). Rodar até verde.
Run: `bundle exec rspec spec/services/custom/messages/forward_service_spec.rb`
Expected: PASS

- [ ] **Step 5: Commit.**
```bash
git add app/services/custom/messages/forward_service.rb spec/services/custom/messages/forward_service_spec.rb
git commit -m "feat(forward): add Custom::Messages::ForwardService"
```

---

### Task 2: Backend — endpoint + rota

**Files:**
- Create: `app/controllers/api/v1/accounts/conversations/forwards_controller.rb`
- Modify: `config/routes.rb` (dentro de `resources :messages` na conversa)
- Test: `spec/controllers/api/v1/accounts/conversations/forwards_controller_spec.rb`

**Interfaces:**
- Produces: `POST /api/v1/accounts/:account_id/conversations/:conversation_id/forwards` body `{ message_ids: [Integer], target_contact_id: Integer }` → `200` com `{ conversation_id: <display_id destino> }`; `422` em validação; `401/403` sem acesso.

- [ ] **Step 1: Write failing request/controller spec**: happy path (agente com acesso → 200, cria outgoing na conversa do contato); 422 quando `target_contact_id` sem telefone ou mensagem não encaminhável; 401 sem login.

- [ ] **Step 2: Run, expect fail (route/controller missing).**
Run: `bundle exec rspec spec/controllers/api/v1/accounts/conversations/forwards_controller_spec.rb`
Expected: FAIL

- [ ] **Step 3: Add route** dentro do bloco da conversa (localizar `resources :conversations` → bloco `member`/`resources :messages`):
```ruby
resources :forwards, only: [:create]
```
(aninhado sob a conversa, como `resources :messages`.)

- [ ] **Step 4: Implement controller.**
```ruby
class Api::V1::Accounts::Conversations::ForwardsController < Api::V1::Accounts::Conversations::BaseController
  def create
    target_contact = Current.account.contacts.find(permitted_params[:target_contact_id])
    target = Custom::Messages::ForwardService.new(
      conversation: @conversation,
      message_ids: Array(permitted_params[:message_ids]),
      target_contact: target_contact,
      user: Current.user
    ).perform
    render json: { conversation_id: target.display_id }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def permitted_params
    params.permit(:conversation_id, :target_contact_id, message_ids: [])
  end
end
```
Conferir a `BaseController` da conversa: ela já carrega `@conversation` e autoriza acesso.

- [ ] **Step 5: Run spec, expect pass.**
Run: `bundle exec rspec spec/controllers/api/v1/accounts/conversations/forwards_controller_spec.rb`
Expected: PASS

- [ ] **Step 6: Commit.**
```bash
git add app/controllers/api/v1/accounts/conversations/forwards_controller.rb config/routes.rb spec/controllers/api/v1/accounts/conversations/forwards_controller_spec.rb
git commit -m "feat(forward): add conversations/forwards endpoint"
```

---

### Task 3: i18n (en, pt_BR, es)

**Files:**
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/en/conversation.json`
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/conversation.json`
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/es/conversation.json`

- [ ] **Step 1:** Adicionar sob `CONVERSATION.CONTEXT_MENU` a chave `"FORWARD"` e um bloco `CONVERSATION.FORWARD` com `TITLE`, `SEARCH_PLACEHOLDER`, `EMPTY`, `SEND`, `SUCCESS`, `ERROR`, `NO_PHONE`. Exemplo (en):
```json
"FORWARD": "Forward",
```
e bloco irmão de `CONTEXT_MENU`:
```json
"FORWARD": {
  "TITLE": "Forward to…",
  "SEARCH_PLACEHOLDER": "Search contacts",
  "EMPTY": "No contacts found",
  "SEND": "Forward",
  "SUCCESS": "Message forwarded",
  "ERROR": "Could not forward the message",
  "NO_PHONE": "This contact has no phone number"
}
```
pt_BR: "Encaminhar", "Encaminhar para…", "Buscar contatos", "Nenhum contato encontrado", "Encaminhar", "Mensagem encaminhada", "Não foi possível encaminhar a mensagem", "Este contato não tem telefone".
es: "Reenviar", "Reenviar a…", "Buscar contactos", "No se encontraron contactos", "Reenviar", "Mensaje reenviado", "No se pudo reenviar el mensaje", "Este contacto no tiene teléfono".

- [ ] **Step 2: Validar coverage.**
Run: `ruby scripts/i18n/fork_translations.rb check`
Expected: PASS (chaves presentes nos 3 idiomas).

- [ ] **Step 3: Commit.**
```bash
git add app/javascript/dashboard/i18n/fazer-ai/locale/*/conversation.json
git commit -m "feat(forward): add i18n for forward message (en, pt_BR, es)"
```

---

### Task 4: Frontend — API + store action

**Files:**
- Modify: `app/javascript/dashboard/api/conversations.js`
- Modify: `app/javascript/dashboard/store/modules/conversations/actions.js`
- Test: `app/javascript/dashboard/store/modules/conversations/specs/actions/forwardSpec.js` (ou adicionar ao spec de actions existente)

**Interfaces:**
- Produces: `ConversationApi.forwardMessages(conversationId, { messageIds, targetContactId })` → `axios.post`.
- Produces: store action `forwardMessages({ conversationId, messageIds, targetContactId })`.

- [ ] **Step 1: Write failing spec** para a action (mocka a API, verifica a chamada e a propagação de erro).

- [ ] **Step 2: Run, expect fail.**
Run: `pnpm test app/javascript/dashboard/store/modules/conversations/specs/actions/forwardSpec.js`
Expected: FAIL

- [ ] **Step 3: Add API method** em `ConversationApi`:
```js
forwardMessages(conversationId, { messageIds, targetContactId }) {
  return axios.post(`${this.url}/${conversationId}/forwards`, {
    message_ids: messageIds,
    target_contact_id: targetContactId,
  });
}
```

- [ ] **Step 4: Add store action** em `actions.js`:
```js
forwardMessages: async (_, { conversationId, messageIds, targetContactId }) => {
  await ConversationApi.forwardMessages(conversationId, {
    messageIds,
    targetContactId,
  });
},
```
(conferir o import de `ConversationApi`/`conversationAPI` já usado no arquivo e seguir o mesmo nome.)

- [ ] **Step 5: Run spec, expect pass.**
Run: `pnpm test app/javascript/dashboard/store/modules/conversations/specs/actions/forwardSpec.js`
Expected: PASS

- [ ] **Step 6: Commit.**
```bash
git add app/javascript/dashboard/api/conversations.js app/javascript/dashboard/store/modules/conversations/actions.js app/javascript/dashboard/store/modules/conversations/specs/actions/forwardSpec.js
git commit -m "feat(forward): add forwardMessages api and store action"
```

---

### Task 5: Frontend — `ForwardWhatsappPanel.vue`

**Files:**
- Create: `app/javascript/dashboard/components-next/message/forward/ForwardWhatsappPanel.vue`
- Test: `app/javascript/dashboard/components-next/message/forward/specs/ForwardWhatsappPanel.spec.js`

**Interfaces:**
- Props: `x: Number`, `y: Number`. Emits: `close`.
- Lê o contexto da mensagem via `useMessageContext()` (id, content, attachments, conversationId). Busca contatos com `createContactSearcher()` de `components-next/NewConversation/helpers/composeConversationHelper`. Ao escolher um contato, dispara `store.dispatch('forwardMessages', { conversationId, messageIds: [id], targetContactId })`, mostra `useAlert(SUCCESS/ERROR)`, emite `close`.

- [ ] **Step 1: Write failing component spec**: renderiza busca; digitar chama o searcher; clicar num contato despacha `forwardMessages` com `{ conversationId, messageIds:[id], targetContactId }` e emite `close`; contato sem telefone → alerta `NO_PHONE` e não despacha.

- [ ] **Step 2: Run, expect fail.**
Run: `pnpm test app/javascript/dashboard/components-next/message/forward/specs/ForwardWhatsappPanel.spec.js`
Expected: FAIL

- [ ] **Step 3: Implement component** usando `ContextMenu` (`dashboard/components/ui/ContextMenu.vue`) como wrapper posicionado em `x/y`, um input de busca, lista de resultados (nome + telefone), e preview enxuto (`content` ou `📎`). Seguir o padrão do `ForwardEmailPanel.vue` para busca (debounce 400ms, `createContactSearcher`). Despacho + alertas conforme interfaces.

- [ ] **Step 4: Run spec, expect pass.**
Run: `pnpm test app/javascript/dashboard/components-next/message/forward/specs/ForwardWhatsappPanel.spec.js`
Expected: PASS

- [ ] **Step 5: Commit.**
```bash
git add app/javascript/dashboard/components-next/message/forward/ForwardWhatsappPanel.vue app/javascript/dashboard/components-next/message/forward/specs/ForwardWhatsappPanel.spec.js
git commit -m "feat(forward): add ForwardWhatsappPanel component"
```

---

### Task 6: Frontend — menu de contexto + Message.vue

**Files:**
- Modify: `app/javascript/dashboard/modules/conversations/components/MessageContextMenu.vue`
- Modify: `app/javascript/dashboard/components-next/message/Message.vue`
- Test: ajustar/adicionar spec de Message (se existir) ou do MessageContextMenu.

**Interfaces:**
- `MessageContextMenu` passa a emitir `forward`; adiciona `MenuItem` quando `enabledOptions['forward']`.
- `Message.vue`: `contextMenuEnabledOptions.forward` = caixa é WhatsApp de sessão (`inbox.channel_type === 'Channel::Whatsapp' && SESSION_PROVIDERS.includes(inbox.provider)`) && não é privada/apagada/atividade/reação && (tem content ou anexo). Ao `@forward`, abre `ForwardWhatsappPanel` (ref + posição, igual ao `showForwardEmail`).

- [ ] **Step 1: Write/adjust failing spec** verificando que o item "Encaminhar" aparece só em caixa WhatsApp de sessão e emite `forward`.

- [ ] **Step 2: Run, expect fail.**

- [ ] **Step 3: MessageContextMenu** — adicionar à lista de `emits` `'forward'`, um `handleForward()` que `$emit('forward')` + `handleClose()`, e um `MenuItem` (ícone `arrow-forward`, label `CONVERSATION.CONTEXT_MENU.FORWARD`) com `v-if="enabledOptions['forward']"`.

- [ ] **Step 4: Message.vue** — importar `SESSION_PROVIDERS` de `dashboard/helper/whatsappSession`; adicionar `forward` em `contextMenuEnabledOptions`; adicionar `showForwardWhatsapp` + `forwardWhatsappPosition` e `openForwardWhatsapp()` (espelhando `openForwardEmail`); no template, `@forward="openForwardWhatsapp"` no `ContextMenu` e renderizar `<ForwardWhatsappPanel v-if="showForwardWhatsapp" .../>`.

- [ ] **Step 5: Run specs, expect pass.** Rodar os specs de Message/ContextMenu afetados.

- [ ] **Step 6: Registrar "Mudanças nossas"** em `.claude/CLAUDE.md` (MessageContextMenu.vue e Message.vue editados; conversation.json overlay) e commit.
```bash
git add app/javascript/dashboard/modules/conversations/components/MessageContextMenu.vue app/javascript/dashboard/components-next/message/Message.vue .claude/CLAUDE.md
git commit -m "feat(forward): wire forward action into message context menu"
```

---

## Self-review

- Cobertura do spec: origem session-only (T1/T6), texto+mídia (T1), criar/reusar conversa (T1), ordem (T1), i18n 3 idiomas (T3), gate de UI (T6) — tudo mapeado.
- Sem placeholders de lógica; código real em cada passo.
- Nomes consistentes: `forwardMessages` (API+store+component), `Custom::Messages::ForwardService`, rota `forwards`.
- Risco conhecido: `MessageBuilder` com hash `with_indifferent_access` (passo T1/Step 4 valida via spec); se `convert_to_hash`/attachments-por-blob falhar, ajustar o service nesse passo antes de seguir.
