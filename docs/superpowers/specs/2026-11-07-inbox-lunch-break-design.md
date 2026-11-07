# Horário de almoço por caixa (pausa dentro do horário comercial)

**Data:** 2026-11-07
**Status:** aprovado (brainstorming)

## Problema

Hoje cada caixa tem 7 `working_hours` (um por dia da semana) com **uma única** janela
abre→fecha. No horário de almoço o relógio cai *dentro* dessa janela, então a caixa é
considerada aberta (`out_of_office?` = false) e a mensagem automática de ausência **não dispara**.
A contabilidade quer que, no almoço, a caixa seja tratada como fechada e a automática dispare.

## Objetivo

Permitir configurar **uma faixa de almoço por caixa** (igual todos os dias; ex.: 12:00–13:30) na
aba "Horário comercial" da caixa. Durante essa faixa, a caixa fica "fechada" e a **mensagem de
ausência já existente** (`out_of_office_message`) dispara — sem texto novo, sem lógica de escolha
de mensagem.

## Contexto do código

- `app/models/concerns/out_of_offisable.rb` (upstream) define `out_of_office?` =
  `working_hours_enabled? && working_hours.today.closed_now?`. A caixa inclui esse concern.
- `app/services/message_templates/template/out_of_office.rb` e
  `app/services/message_templates/hook_execution_service.rb` disparam a automática **apenas** com
  base em `inbox.out_of_office?` (+ `out_of_office_message` presente + nenhum template hoje).
  Logo, basta `out_of_office?` virar `true` no almoço.
- `app/models/inbox.rb` já inclui nosso `Custom::InboxCustomColor` por uma linha — mesmo padrão.
- A tela é `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WeeklyAvailability.vue`;
  o salvar monta um payload e faz `inboxes/updateInbox`. O serializer é
  `app/views/api/v1/models/_inbox.json.jbuilder`; os params permitidos ficam em
  `app/controllers/api/v1/accounts/inboxes_controller.rb` (`inbox_attributes`) — ambos já editados
  por nós para `custom_color`.

## Modelo de dados

Migration nova e idempotente: coluna `custom_lunch_break` (**jsonb**, default `{}`) em `inboxes`.

Formato guardado:

```json
{ "enabled": true, "start_hour": 12, "start_minutes": 0, "end_hour": 13, "end_minutes": 30 }
```

Usar jsonb (um campo só) em vez de 5 colunas soltas mantém a migration e o schema enxutos.

## Comportamento (backend)

Concern novo `app/models/concerns/custom/inbox_lunch_break.rb`, incluído em `inbox.rb` por **uma
linha, depois do `include OutOfOffisable`** (para que o `super` resolva para a implementação do
upstream):

```ruby
module Custom::InboxLunchBreak
  extend ActiveSupport::Concern

  def out_of_office?
    return true if super

    within_lunch_break_now?
  end

  def lunch_break
    (custom_lunch_break || {}).with_indifferent_access
  end

  def lunch_break_enabled?
    working_hours_enabled? && ActiveModel::Type::Boolean.new.cast(lunch_break[:enabled])
  end

  private

  def within_lunch_break_now?
    return false unless lunch_break_enabled?

    now = Time.zone.now.in_time_zone(timezone)
    start_time = now.change(hour: lunch_break[:start_hour].to_i, min: lunch_break[:start_minutes].to_i)
    end_time   = now.change(hour: lunch_break[:end_hour].to_i,   min: lunch_break[:end_minutes].to_i)
    now.between?(start_time, end_time)
  end
end
```

Pontos:
- `super` cobre "fora do expediente" (dia fechado / fora da janela). O almoço só adiciona o
  "fechado no meio do dia".
- `lunch_break_enabled?` exige `working_hours_enabled?` — sem horário comercial ativo não há
  conceito de pausa, então o almoço não fecha uma caixa sempre-aberta.
- Fuso: usa `inbox.timezone`, igual o `WorkingHour`.

Validação no concern (via `validate`): quando `enabled`, horas 0–23 e minutos 0–59, e fim depois
do início. Mensagens de erro curtas.

## UI

Em `WeeklyAvailability.vue`, dentro do bloco `v-if="isBusinessHoursEnabled"` (abaixo do fuso,
acima/junto da tabela semanal), um bloco **"Horário de almoço"**:

- Toggle liga/desliga (`SettingsToggleSection`).
- Quando ligado: dois seletores de hora (início e fim), reusando o mesmo padrão de horário dos
  `BusinessDay`/helpers de `businessHour`.
- `setDefaults()` lê `this.inbox.custom_lunch_break`; `updateInbox()` inclui
  `custom_lunch_break: { enabled, start_hour, start_minutes, end_hour, end_minutes }` no payload.
- Erro de validação (fim antes do início) bloqueia o submit junto do `hasError` já existente.

Para manter a edição do upstream pequena, extrair o bloco para um componente nosso
`app/javascript/dashboard/components/custom/InboxLunchBreak.vue` e só montá-lo (import + 1 tag)
dentro do `WeeklyAvailability.vue`, com `v-model`/eventos para o pai compor o payload.

## Serialização / params

- `app/views/api/v1/models/_inbox.json.jbuilder` — `json.custom_lunch_break resource.custom_lunch_break`.
- `app/controllers/api/v1/accounts/inboxes_controller.rb` — permitir
  `custom_lunch_break: [:enabled, :start_hour, :start_minutes, :end_hour, :end_minutes]` em
  `inbox_attributes`.

## Fora de escopo (YAGNI)

- Faixa de almoço diferente por dia da semana (escolhido: uma só, igual todos os dias).
- Texto de mensagem próprio pro almoço (reusa `out_of_office_message`).
- Mais de uma pausa por dia.

## Testes

- **Model/concern** (`spec/models/concerns/custom/inbox_lunch_break_spec.rb` ou no inbox spec):
  - `out_of_office?` = true dentro da faixa de almoço (horário comercial ativo, dia aberto).
  - `out_of_office?` = false fora da faixa (dentro do expediente, fora do almoço).
  - `out_of_office?` respeita o `super`: fora do expediente continua true.
  - almoço desligado → sem efeito; `working_hours_enabled?` false → sem efeito.
  - usa o fuso da caixa (teste com `timezone` != UTC cruzando a borda).
  - validação: fim antes do início inválido.
- **Request/serializer**: `custom_lunch_break` volta no JSON da caixa e é aceito no update
  (params permitidos).

## Arquivos tocados

Upstream (aditivo, registrar em `.claude/CLAUDE.md` → "Mudanças nossas"):
- `app/models/inbox.rb` (1 linha de `include`, depois do `OutOfOffisable`)
- `app/views/api/v1/models/_inbox.json.jbuilder`
- `app/controllers/api/v1/accounts/inboxes_controller.rb`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WeeklyAvailability.vue`

Nosso:
- `db/migrate/XXXX_add_custom_lunch_break_to_inboxes.rb` (idempotente)
- `app/models/concerns/custom/inbox_lunch_break.rb`
- `app/javascript/dashboard/components/custom/InboxLunchBreak.vue`
- i18n no overlay `app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/inboxMgmt.json` (en, pt_BR, es)
