# Cor por caixa de entrada — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar a cada caixa de entrada uma cor configurável (uma só, de uma paleta fixa) que aparece como etiqueta colorida no nome da caixa na lista de conversas e como cor do balão enviado na conversa aberta.

**Architecture:** Uma coluna `custom_color` (string, hex) em `inboxes`, validada contra uma paleta canônica. O atributo desce pelo serializer da inbox e volta pelo controller. No frontend, uma constante compartilha a mesma paleta; um componente nosso de seleção grava a cor via o update de inbox existente; os dois componentes `InboxName` pintam o rótulo; e o balão enviado (variante `AGENT`) é recolorido via uma variável CSS definida no wrapper da conversa (que conhece a inbox atual).

**Tech Stack:** Rails (ActiveRecord, jbuilder, RSpec), Vue 3 (Options API em telas existentes, `<script setup>` em componentes novos), Tailwind, vitest + @vue/test-utils.

## Global Constraints

- Responder em pt-BR com o usuário; código/comentários/commits em inglês (padrão do repo).
- Fork barato de merge: preferir arquivos NOVOS; editar arquivo do upstream só quando não há outro jeito, com mudança mínima, e REGISTRAR em `.claude/CLAUDE.md` (seção "Mudanças nossas").
- Namespace do que é nosso: prefixo/namespace `custom`.
- Migrations novas IDEMPOTENTES (`unless column_exists?`). Criar via `bundle exec rails g migration` (timestamp real). Sem SQL cru.
- i18n: toda chave nova em **en, pt_BR e es**, SEMPRE nos arquivos do overlay do fork (`app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/*.json`). Nunca nos locales do upstream.
- Tailwind only no estilo; exceção justificada: cores vindas do banco (hex dinâmico) entram por `:style` inline / variável CSS, não por classe utilitária compilada.
- Branch já criada: `feat/inbox-color`. Commits frequentes. Não dar push nem abrir PR sem o usuário pedir.
- Paleta canônica (10 cores, escuras o bastante para texto branco no balão e para o mesmo hex como texto sobre fundo a ~12%). Valores EXATOS, usados idênticos no backend e no frontend:

  `#9F1239`, `#B91C1C`, `#B45309`, `#15803D`, `#0F766E`, `#0E7490`, `#1D4ED8`, `#4338CA`, `#6D28D9`, `#BE185D`

---

### Task 1: Backend — coluna, paleta e validação no modelo

**Files:**
- Create: `db/migrate/<timestamp>_add_custom_color_to_inboxes.rb` (gerado)
- Create: `app/models/concerns/custom/inbox_custom_color.rb`
- Modify: `app/models/inbox.rb:51` (adicionar o `include`)
- Test: `spec/models/inbox_spec.rb` (adicionar exemplos de validação de `custom_color`)

**Interfaces:**
- Produces: `inboxes.custom_color` (string, nullable); `Custom::InboxCustomColor::PALETTE` (array de 10 hex em maiúsculas); validação `inclusion` com `allow_nil: true`.

- [ ] **Step 1: Gerar a migration**

Run: `bundle exec rails g migration AddCustomColorToInboxes custom_color:string`
Expected: cria `db/migrate/<timestamp>_add_custom_color_to_inboxes.rb`.

- [ ] **Step 2: Tornar a migration idempotente**

Substituir o corpo do arquivo gerado por:

```ruby
class AddCustomColorToInboxes < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:inboxes, :custom_color)

    add_column :inboxes, :custom_color, :string
  end
end
```

(Mantenha a versão `[7.x]` que o gerador escreveu.)

- [ ] **Step 3: Rodar a migration**

Run: `bundle exec rails db:migrate`
Expected: `add_column(:inboxes, :custom_color...)` aplicado; `db/schema.rb` passa a listar `t.string "custom_color"` em `inboxes`.

- [ ] **Step 4: Escrever o concern com paleta + validação**

Create `app/models/concerns/custom/inbox_custom_color.rb`:

```ruby
module Custom::InboxCustomColor
  extend ActiveSupport::Concern

  # Canonical palette for the per-inbox color. Keep in sync with the frontend
  # copy in app/javascript/dashboard/constants/customInboxColors.js.
  PALETTE = %w[
    #9F1239 #B91C1C #B45309 #15803D #0F766E
    #0E7490 #1D4ED8 #4338CA #6D28D9 #BE185D
  ].freeze

  included do
    validates :custom_color, inclusion: { in: PALETTE }, allow_nil: true
  end
end
```

- [ ] **Step 5: Incluir o concern no modelo**

Modify `app/models/inbox.rb` — após a linha `include InboxBotStatus` (linha 51), acrescentar:

```ruby
  include Custom::InboxCustomColor
```

- [ ] **Step 6: Escrever os specs de validação (falhando)**

Adicionar em `spec/models/inbox_spec.rb` (dentro do bloco `RSpec.describe Inbox`):

```ruby
  describe 'custom_color validation' do
    let(:inbox) { create(:inbox) }

    it 'accepts nil' do
      inbox.custom_color = nil
      expect(inbox).to be_valid
    end

    it 'accepts a color from the palette' do
      inbox.custom_color = Custom::InboxCustomColor::PALETTE.first
      expect(inbox).to be_valid
    end

    it 'rejects a color outside the palette' do
      inbox.custom_color = '#123456'
      expect(inbox).not_to be_valid
      expect(inbox.errors[:custom_color]).to be_present
    end
  end
```

- [ ] **Step 7: Rodar os specs**

Run: `bundle exec rspec spec/models/inbox_spec.rb -e "custom_color validation"`
Expected: 3 exemplos, PASS.

- [ ] **Step 8: Commit**

```bash
git add db/migrate app/models/concerns/custom/inbox_custom_color.rb app/models/inbox.rb db/schema.rb spec/models/inbox_spec.rb
git commit -m "feat(inbox): add custom_color column with palette validation"
```

---

### Task 2: Backend — serializer e params do controller

**Files:**
- Modify: `app/views/api/v1/models/_inbox.json.jbuilder:24` (adicionar 1 linha após `business_name`)
- Modify: `app/controllers/api/v1/accounts/inboxes_controller.rb:356` (adicionar `:custom_color` em `inbox_attributes`)
- Test: `spec/controllers/api/v1/accounts/inboxes_controller_spec.rb` (serialização + update)

**Interfaces:**
- Consumes: `inboxes.custom_color`, `Custom::InboxCustomColor::PALETTE` (Task 1).
- Produces: payload da inbox com a chave `custom_color`; o endpoint `PATCH /api/v1/accounts/:account_id/inboxes/:id` aceita `custom_color` (top-level).

- [ ] **Step 1: Escrever os specs (falhando)**

Adicionar em `spec/controllers/api/v1/accounts/inboxes_controller_spec.rb`. Localize o `describe '#update'` e o `describe '#show'` existentes e acrescente, como administrador autenticado:

```ruby
    it 'serializes custom_color' do
      inbox.update!(custom_color: Custom::InboxCustomColor::PALETTE.first)

      get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}",
          headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['custom_color']).to eq(Custom::InboxCustomColor::PALETTE.first)
    end

    it 'updates custom_color from the palette' do
      patch "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}",
            params: { custom_color: Custom::InboxCustomColor::PALETTE.last },
            headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(inbox.reload.custom_color).to eq(Custom::InboxCustomColor::PALETTE.last)
    end

    it 'rejects a custom_color outside the palette' do
      patch "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}",
            params: { custom_color: '#123456' },
            headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
```

(Use os `let(:account)`, `let(:admin)`, `let(:inbox)` já definidos no arquivo; ajuste os nomes se diferirem — confira o topo do describe antes de rodar.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/controllers/api/v1/accounts/inboxes_controller_spec.rb -e custom_color`
Expected: FAIL (chave ausente no payload / param não persistido).

- [ ] **Step 3: Serializar o atributo**

Modify `app/views/api/v1/models/_inbox.json.jbuilder` — após a linha `json.business_name resource.business_name` (linha 24), acrescentar:

```ruby
json.custom_color resource.custom_color
```

- [ ] **Step 4: Permitir o param**

Modify `app/controllers/api/v1/accounts/inboxes_controller.rb` — na lista `inbox_attributes` (linha 353-361), acrescentar `:custom_color` ao array de símbolos (ex.: logo após `:business_name` na linha 356):

```ruby
     :lock_to_single_conversation, :prevent_assignment_takeover, :drop_assignee_outside_team_on_reopen, :portal_id, :sender_name_type, :business_name, :custom_color,
```

- [ ] **Step 5: Rodar e ver passar**

Run: `bundle exec rspec spec/controllers/api/v1/accounts/inboxes_controller_spec.rb -e custom_color`
Expected: 3 exemplos, PASS.

- [ ] **Step 6: Commit**

```bash
git add app/views/api/v1/models/_inbox.json.jbuilder app/controllers/api/v1/accounts/inboxes_controller.rb spec/controllers/api/v1/accounts/inboxes_controller_spec.rb
git commit -m "feat(inbox): expose and accept custom_color over the API"
```

---

### Task 3: i18n — chaves do seletor (en, pt_BR, es)

**Files:**
- Create/Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/en/inboxMgmt.json`
- Create/Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/inboxMgmt.json`
- Create/Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/es/inboxMgmt.json`

**Interfaces:**
- Produces as chaves `INBOX_MGMT.CUSTOM_COLOR.LABEL`, `.DESCRIPTION`, `.NONE` nos três locales.

> Nota: se o arquivo já existir no overlay, faça merge do objeto `INBOX_MGMT` (deep-merge no runtime; não duplicar a chave de topo se já houver uma). Se não existir, crie com a estrutura abaixo.

- [ ] **Step 1: en**

`app/javascript/dashboard/i18n/fazer-ai/locale/en/inboxMgmt.json` deve conter:

```json
{
  "INBOX_MGMT": {
    "CUSTOM_COLOR": {
      "LABEL": "Inbox color",
      "DESCRIPTION": "Used to tint the inbox name in the conversation list and the sent message bubbles.",
      "NONE": "No color"
    }
  }
}
```

- [ ] **Step 2: pt_BR**

`app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/inboxMgmt.json`:

```json
{
  "INBOX_MGMT": {
    "CUSTOM_COLOR": {
      "LABEL": "Cor da caixa",
      "DESCRIPTION": "Usada para colorir o nome da caixa na lista de conversas e os balões das mensagens enviadas.",
      "NONE": "Sem cor"
    }
  }
}
```

- [ ] **Step 3: es**

`app/javascript/dashboard/i18n/fazer-ai/locale/es/inboxMgmt.json`:

```json
{
  "INBOX_MGMT": {
    "CUSTOM_COLOR": {
      "LABEL": "Color de la bandeja",
      "DESCRIPTION": "Se usa para colorear el nombre de la bandeja en la lista de conversaciones y las burbujas de los mensajes enviados.",
      "NONE": "Sin color"
    }
  }
}
```

- [ ] **Step 4: Rodar o check de i18n do fork**

Run: `ruby scripts/i18n/fork_translations.rb check`
Expected: PASS (as 3 chaves presentes em en, pt_BR e es; sem edição em locale do upstream).

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/i18n/fazer-ai/locale/en/inboxMgmt.json app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/inboxMgmt.json app/javascript/dashboard/i18n/fazer-ai/locale/es/inboxMgmt.json
git commit -m "chore(i18n): add inbox custom color strings (en, pt_BR, es)"
```

---

### Task 4: Frontend — paleta compartilhada + componente de seleção

**Files:**
- Create: `app/javascript/dashboard/constants/customInboxColors.js`
- Create: `app/javascript/dashboard/components/custom/InboxColorPicker.vue`
- Test: `app/javascript/dashboard/components/custom/specs/InboxColorPicker.spec.js`

**Interfaces:**
- Produces: `INBOX_COLOR_PALETTE` (array dos 10 hex, idênticos ao backend); componente `InboxColorPicker` com prop `modelValue: String|null` e evento `update:modelValue` emitindo o hex escolhido ou `null` ("Sem cor").

- [ ] **Step 1: Criar a constante da paleta**

Create `app/javascript/dashboard/constants/customInboxColors.js`:

```js
// Canonical palette for the per-inbox color. Keep in sync with the backend
// copy in app/models/concerns/custom/inbox_custom_color.rb.
export const INBOX_COLOR_PALETTE = [
  '#9F1239',
  '#B91C1C',
  '#B45309',
  '#15803D',
  '#0F766E',
  '#0E7490',
  '#1D4ED8',
  '#4338CA',
  '#6D28D9',
  '#BE185D',
];
```

- [ ] **Step 2: Escrever o spec do componente (falhando)**

Create `app/javascript/dashboard/components/custom/specs/InboxColorPicker.spec.js`:

```js
import { mount } from '@vue/test-utils';
import InboxColorPicker from '../InboxColorPicker.vue';
import { INBOX_COLOR_PALETTE } from 'dashboard/constants/customInboxColors';

const globalConfig = {
  mocks: { $t: key => key },
};

describe('InboxColorPicker', () => {
  it('renders a swatch per palette color plus the "no color" option', () => {
    const wrapper = mount(InboxColorPicker, {
      props: { modelValue: null },
      global: globalConfig,
    });
    expect(wrapper.findAll('[data-testid="color-swatch"]')).toHaveLength(
      INBOX_COLOR_PALETTE.length
    );
    expect(wrapper.find('[data-testid="color-none"]').exists()).toBe(true);
  });

  it('emits the chosen color', async () => {
    const wrapper = mount(InboxColorPicker, {
      props: { modelValue: null },
      global: globalConfig,
    });
    await wrapper.findAll('[data-testid="color-swatch"]')[2].trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([
      INBOX_COLOR_PALETTE[2],
    ]);
  });

  it('emits null when "no color" is chosen', async () => {
    const wrapper = mount(InboxColorPicker, {
      props: { modelValue: INBOX_COLOR_PALETTE[0] },
      global: globalConfig,
    });
    await wrapper.find('[data-testid="color-none"]').trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([null]);
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `pnpm test app/javascript/dashboard/components/custom/specs/InboxColorPicker.spec.js`
Expected: FAIL (componente não existe).

- [ ] **Step 4: Implementar o componente**

Create `app/javascript/dashboard/components/custom/InboxColorPicker.vue`:

```vue
<script setup>
import { INBOX_COLOR_PALETTE } from 'dashboard/constants/customInboxColors';

const props = defineProps({
  modelValue: { type: String, default: null },
});
const emit = defineEmits(['update:modelValue']);

const palette = INBOX_COLOR_PALETTE;

const select = color => emit('update:modelValue', color);
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <button
      v-for="color in palette"
      :key="color"
      type="button"
      data-testid="color-swatch"
      class="size-6 rounded-full border border-n-weak transition-transform hover:scale-110"
      :class="modelValue === color ? 'ring-2 ring-offset-2 ring-n-slate-11' : ''"
      :style="{ backgroundColor: color }"
      :title="color"
      @click="select(color)"
    />
    <button
      type="button"
      data-testid="color-none"
      class="flex items-center gap-1 px-2 h-6 rounded-full border border-n-weak text-label-small text-n-slate-11"
      :class="modelValue === null ? 'ring-2 ring-offset-2 ring-n-slate-11' : ''"
      @click="select(null)"
    >
      {{ $t('INBOX_MGMT.CUSTOM_COLOR.NONE') }}
    </button>
  </div>
</template>
```

- [ ] **Step 5: Rodar e ver passar**

Run: `pnpm test app/javascript/dashboard/components/custom/specs/InboxColorPicker.spec.js`
Expected: 3 testes, PASS.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/constants/customInboxColors.js app/javascript/dashboard/components/custom/InboxColorPicker.vue app/javascript/dashboard/components/custom/specs/InboxColorPicker.spec.js
git commit -m "feat(inbox): add shared color palette and InboxColorPicker"
```

---

### Task 5: Frontend — montar o seletor na aba geral da caixa

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue` (import + registro + data + init + payload + template)

**Interfaces:**
- Consumes: `InboxColorPicker` (Task 4), chaves i18n `INBOX_MGMT.CUSTOM_COLOR.*` (Task 3), endpoint de update que aceita `custom_color` (Task 2).
- Produces: o campo de cor salva `custom_color` ao clicar em "Update" (o botão `@click="updateInbox"` já existente).

- [ ] **Step 1: Importar e registrar o componente**

Modify `Settings.vue` — na lista de imports (perto da linha 54, onde o `ColorPicker` do widget é importado), acrescentar:

```js
import InboxColorPicker from 'dashboard/components/custom/InboxColorPicker.vue';
```

E no objeto `components` (perto da linha 92), acrescentar `InboxColorPicker,`.

- [ ] **Step 2: Adicionar o estado**

Em `data()` (perto da linha 127, junto de `selectedInboxName: ''`), acrescentar:

```js
      selectedCustomColor: null,
```

- [ ] **Step 3: Inicializar a partir da inbox**

Modify `Settings.vue:639` — logo após `this.selectedInboxName = this.inbox.name;`, acrescentar:

```js
      this.selectedCustomColor = this.inbox.custom_color || null;
```

- [ ] **Step 4: Incluir no payload do update**

Modify o método `updateInbox()` (payload a partir da linha 801). Logo após `business_name: this.businessName || null,` (linha 815), acrescentar no nível top do payload:

```js
          custom_color: this.selectedCustomColor,
```

- [ ] **Step 5: Renderizar o seletor na aba geral**

Modify o template — logo após o `</SettingsFieldSection>` do nome da caixa (fecha na linha 1077), acrescentar:

```vue
            <SettingsFieldSection
              :label="$t('INBOX_MGMT.CUSTOM_COLOR.LABEL')"
            >
              <p class="mb-2 text-label-small text-n-slate-11">
                {{ $t('INBOX_MGMT.CUSTOM_COLOR.DESCRIPTION') }}
              </p>
              <InboxColorPicker v-model="selectedCustomColor" />
            </SettingsFieldSection>
```

- [ ] **Step 6: Verificação manual (sem spec dedicado — é fiação de tela)**

Run: `pnpm dev` (ou o ambiente já rodando). Abrir Configurações → uma caixa → aba de configurações (geral). Conferir: a seção "Cor da caixa" aparece abaixo do nome; escolher uma cor e clicar em "Update" salva; reabrir mostra a cor selecionada; "Sem cor" limpa.
Expected: a cor persiste (confirma Task 2 de ponta a ponta).

- [ ] **Step 7: Lint e commit**

Run: `pnpm eslint:fix app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`

```bash
git add app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue
git commit -m "feat(inbox): add inbox color picker to the inbox settings tab"
```

---

### Task 6: Frontend — etiqueta colorida no nome da caixa (dois componentes InboxName)

**Files:**
- Modify: `app/javascript/dashboard/components/widgets/InboxName.vue` (card antigo / layout padrão do print)
- Modify: `app/javascript/dashboard/components-next/Conversation/InboxName.vue` (card expandido + cabeçalho da conversa)
- Test: `app/javascript/dashboard/components-next/Conversation/specs/InboxName.spec.js`

**Interfaces:**
- Consumes: `inbox.custom_color` (do payload serializado em Task 2).
- Produces: quando `inbox.custom_color` existe, o rótulo vira pílula (texto na cor + fundo a ~12% da cor); sem cor, mantém o estilo atual.

> Padrão do tingimento (idêntico nos dois arquivos): aplicar no `<span>` do nome.
> - `:style` quando há cor: `{ color: inbox.custom_color, backgroundColor: inbox.custom_color + '1F' }` (o sufixo `1F` é ~12% de alpha em hex de 8 dígitos; válido para os hex de 6 dígitos da paleta).
> - classes extra quando há cor: `px-1.5 py-0.5 rounded-full`.

- [ ] **Step 1: Escrever o spec (falhando) para o InboxName do components-next**

Create `app/javascript/dashboard/components-next/Conversation/specs/InboxName.spec.js`:

```js
import { mount } from '@vue/test-utils';
import InboxName from '../InboxName.vue';

const mountWith = inbox =>
  mount(InboxName, {
    props: { inbox },
    global: { stubs: { ChannelIcon: true } },
  });

describe('InboxName', () => {
  it('tints the name when the inbox has a custom color', () => {
    const wrapper = mountWith({ name: 'Ágeis', custom_color: '#9F1239' });
    const span = wrapper.find('span');
    expect(span.attributes('style')).toContain('color: rgb(159, 18, 57)');
    expect(span.attributes('style')).toContain('background-color');
    expect(span.classes()).toContain('rounded-full');
  });

  it('keeps the default style without a custom color', () => {
    const wrapper = mountWith({ name: 'Ágeis' });
    const span = wrapper.find('span');
    expect(span.classes()).not.toContain('rounded-full');
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `pnpm test app/javascript/dashboard/components-next/Conversation/specs/InboxName.spec.js`
Expected: FAIL.

- [ ] **Step 3: Tingir o InboxName do components-next**

Modify `app/javascript/dashboard/components-next/Conversation/InboxName.vue` — trocar o `<span>` do nome por:

```vue
    <span
      class="truncate text-body-main"
      :class="
        inbox.custom_color
          ? 'px-1.5 py-0.5 rounded-full'
          : 'text-n-slate-11'
      "
      :style="
        inbox.custom_color
          ? {
              color: inbox.custom_color,
              backgroundColor: `${inbox.custom_color}1F`,
            }
          : {}
      "
    >
      {{ inbox.name }}
    </span>
```

- [ ] **Step 4: Rodar e ver passar**

Run: `pnpm test app/javascript/dashboard/components-next/Conversation/specs/InboxName.spec.js`
Expected: 2 testes, PASS.

- [ ] **Step 5: Tingir o InboxName antigo (o do print)**

Modify `app/javascript/dashboard/components/widgets/InboxName.vue` — trocar o `<span>` do nome (hoje `class="truncate text-label-small text-n-slate-11"`) por:

```vue
    <span
      class="truncate text-label-small"
      :class="
        inbox.custom_color ? 'px-1.5 py-0.5 rounded-full' : 'text-n-slate-11'
      "
      :style="
        inbox.custom_color
          ? {
              color: inbox.custom_color,
              backgroundColor: `${inbox.custom_color}1F`,
            }
          : {}
      "
    >
      {{ inbox.name }}
    </span>
```

- [ ] **Step 6: Lint e commit**

Run: `pnpm eslint:fix app/javascript/dashboard/components/widgets/InboxName.vue app/javascript/dashboard/components-next/Conversation/InboxName.vue`

```bash
git add app/javascript/dashboard/components/widgets/InboxName.vue app/javascript/dashboard/components-next/Conversation/InboxName.vue app/javascript/dashboard/components-next/Conversation/specs/InboxName.spec.js
git commit -m "feat(inbox): tint the inbox name label with the inbox color"
```

---

### Task 7: Frontend — balão enviado na cor da caixa

**Files:**
- Modify: `app/javascript/dashboard/components-next/message/bubbles/Base.vue` (marcar a variante AGENT)
- Modify: `app/javascript/dashboard/components-next/message/Message.vue` (regra CSS global no bloco `<style>` existente)
- Modify: `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` (definir a variável CSS no wrapper)
- Test: `app/javascript/dashboard/routes/dashboard/conversation/specs/conversationViewInboxColor.spec.js`

**Interfaces:**
- Consumes: `inbox.custom_color` da inbox da conversa atual (store getter `inboxes/getInbox`).
- Produces: quando a inbox da conversa tem cor, o wrapper da conversa define `--inbox-send-bubble: <hex>` e a classe `has-inbox-bubble-color`; os balões `AGENT` (marcados com `agent-bubble`) passam a usar esse fundo com texto branco. Sem cor: nada muda (azul atual).

- [ ] **Step 1: Marcar a variante AGENT no Base.vue**

Modify `app/javascript/dashboard/components-next/message/bubbles/Base.vue` — na `varaintBaseMap`, acrescentar a classe `agent-bubble` à entrada AGENT (linha 54):

```js
  [MESSAGE_VARIANTS.AGENT]: 'agent-bubble bg-n-solid-blue text-n-slate-12',
```

(As demais entradas ficam inalteradas. A classe `agent-bubble` é só um marcador para o CSS; não muda nada sozinha.)

- [ ] **Step 2: Adicionar a regra CSS global**

Modify `app/javascript/dashboard/components-next/message/Message.vue` — no bloco `<style lang="scss">` existente (linhas 937-947, não-scoped), acrescentar:

```scss
.has-inbox-bubble-color .agent-bubble {
  background: var(--inbox-send-bubble) !important;
  color: #fff !important;
}
```

- [ ] **Step 3: Escrever o spec (falhando) do wrapper**

Create `app/javascript/dashboard/routes/dashboard/conversation/specs/conversationViewInboxColor.spec.js`.

Testar a lógica pura que deriva o estilo a partir da cor da inbox. Importe o helper que a Task cria no passo 4 (`inboxBubbleStyle`):

```js
import { inboxBubbleStyle } from '../inboxBubbleStyle';

describe('inboxBubbleStyle', () => {
  it('returns the css var and marker class when the inbox has a color', () => {
    expect(inboxBubbleStyle('#9F1239')).toEqual({
      class: 'has-inbox-bubble-color',
      style: { '--inbox-send-bubble': '#9F1239' },
    });
  });

  it('returns no class/style when there is no color', () => {
    expect(inboxBubbleStyle(null)).toEqual({ class: '', style: {} });
  });
});
```

- [ ] **Step 4: Criar o helper puro**

Create `app/javascript/dashboard/routes/dashboard/conversation/inboxBubbleStyle.js`:

```js
// Derives the wrapper class + CSS var used to recolor the outgoing (agent)
// message bubbles with the conversation inbox color. Kept pure for testing.
export const inboxBubbleStyle = customColor => {
  if (!customColor) return { class: '', style: {} };
  return {
    class: 'has-inbox-bubble-color',
    style: { '--inbox-send-bubble': customColor },
  };
};
```

- [ ] **Step 5: Rodar e ver passar**

Run: `pnpm test app/javascript/dashboard/routes/dashboard/conversation/specs/conversationViewInboxColor.spec.js`
Expected: 2 testes, PASS.

- [ ] **Step 6: Usar o helper no ConversationView**

Modify `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue`:

1. No topo do `<script>`, importar o helper:

```js
import { inboxBubbleStyle } from './inboxBubbleStyle';
```

2. Em `computed`, acrescentar (o `getSelectedChat` já está mapeado como `currentChat`; a inbox vem do getter `inboxes/getInbox`):

```js
    currentInboxBubble() {
      const inbox = this.$store.getters['inboxes/getInbox'](
        this.currentChat?.inbox_id
      );
      return inboxBubbleStyle(inbox?.custom_color);
    },
```

3. No elemento raiz do `<template>` (o `<div>` que envolve a conversa), vincular classe e estilo:

```vue
    :class="currentInboxBubble.class"
    :style="currentInboxBubble.style"
```

(Se o raiz já tiver `:class`/`:style`, combine num array/objeto em vez de sobrescrever.)

- [ ] **Step 7: Verificação manual**

Abrir uma conversa de uma caixa COM cor: os balões enviados ficam na cor da caixa com texto branco; os recebidos seguem cinza. Abrir uma conversa de caixa SEM cor: balão enviado azul (inalterado).
Expected: conforme descrito.

- [ ] **Step 8: Lint e commit**

Run: `pnpm eslint:fix app/javascript/dashboard/components-next/message/bubbles/Base.vue app/javascript/dashboard/components-next/message/Message.vue app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue app/javascript/dashboard/routes/dashboard/conversation/inboxBubbleStyle.js`

```bash
git add app/javascript/dashboard/components-next/message/bubbles/Base.vue app/javascript/dashboard/components-next/message/Message.vue app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue app/javascript/dashboard/routes/dashboard/conversation/inboxBubbleStyle.js app/javascript/dashboard/routes/dashboard/conversation/specs/conversationViewInboxColor.spec.js
git commit -m "feat(inbox): color outgoing message bubbles with the inbox color"
```

---

### Task 8: Registrar as mudanças no upstream (CLAUDE.md do fork)

**Files:**
- Modify: `.claude/CLAUDE.md` (seção "Mudanças nossas em arquivos do upstream")

**Interfaces:**
- Consumes: as edições de upstream feitas nas Tasks 1, 2, 5, 6, 7.

- [ ] **Step 1: Acrescentar a entrada**

Modify `.claude/CLAUDE.md` — na seção "## Mudanças nossas em arquivos do upstream", acrescentar um item:

```markdown
- **Cor por caixa** (`custom_color` em `inboxes`): arquivos do upstream tocados —
  `app/models/inbox.rb` (1 `include`), `app/views/api/v1/models/_inbox.json.jbuilder` (1 linha),
  `app/controllers/api/v1/accounts/inboxes_controller.rb` (`:custom_color` em `inbox_attributes`),
  `routes/dashboard/settings/inbox/Settings.vue` (seletor na aba geral),
  `components/widgets/InboxName.vue` + `components-next/Conversation/InboxName.vue` (etiqueta tingida),
  `components-next/message/bubbles/Base.vue` (marcador `agent-bubble`) +
  `components-next/message/Message.vue` (regra CSS) +
  `routes/dashboard/conversation/ConversationView.vue` (variável CSS no wrapper).
  Lógica nossa: `app/models/concerns/custom/inbox_custom_color.rb`,
  `dashboard/constants/customInboxColors.js`, `dashboard/components/custom/InboxColorPicker.vue`,
  `routes/dashboard/conversation/inboxBubbleStyle.js`. Reverter = tirar o include/linha/param e os
  bindings, e dropar a coluna. A paleta é duplicada (backend/concern ↔ frontend/const): manter em sincronia.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/CLAUDE.md
git commit -m "docs(fork): register per-inbox color upstream edits"
```

---

## Self-Review

**Spec coverage:**
- Config na caixa (paleta pronta) → Tasks 3, 4, 5. ✅
- Etiqueta colorida na lista (opção C) → Task 6 (os dois InboxName). ✅
- Balão enviado na cor; recebido inalterado → Task 7. ✅
- Uma cor por caixa, da paleta fixa → paleta única (Tasks 1, 4), validação (Task 1). ✅
- Caixa sem cor = visual atual → ramos `custom_color ?` em Tasks 6, 7. ✅
- Armazenamento + serializer + param (edições mínimas no upstream) → Tasks 1, 2. ✅
- i18n en/pt_BR/es no overlay → Task 3. ✅
- Registro das mudanças no upstream → Task 8. ✅

**Placeholder scan:** sem TBD/TODO; todo passo que muda código mostra o código. Os anchors citam arquivo:linha reais verificados.

**Type/nome consistency:** `custom_color` (backend/serializer/param/store payload) ↔ `selectedCustomColor` (estado da tela) ↔ `INBOX_COLOR_PALETTE`/`Custom::InboxCustomColor::PALETTE` (paleta) ↔ `inboxBubbleStyle`/`--inbox-send-bubble`/`.has-inbox-bubble-color`/`.agent-bubble` (balão) — consistentes entre as tasks.

> Riscos conhecidos a validar na execução:
> - O elemento raiz do `ConversationView.vue` pode já ter `:class`/`:style` — combinar, não sobrescrever (Task 7, passo 6).
> - Os nomes de `let` no controller spec (`account`/`admin`/`inbox`) podem diferir — conferir o topo do describe (Task 2, passo 1).
> - Se o `inboxMgmt.json` do overlay já existir, fazer deep-merge do `INBOX_MGMT` (Task 3).
