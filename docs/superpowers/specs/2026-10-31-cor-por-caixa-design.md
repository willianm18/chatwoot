# Cor por caixa de entrada

**Data:** 2026-10-31
**Status:** Aprovado (brainstorming) — pronto para plano de implementação
**Fork:** willianm18/chatwoot (sobre fazer-ai/chatwoot)

## Problema

Os atendentes trabalham várias caixas de WhatsApp na mesma lista de conversas (ex.:
"Ágeis - Atendimento", "Sand - Atendimento"). Hoje só o **nome** da caixa diferencia uma da
outra, o que obriga a ler o texto para saber de qual caixa é cada conversa. O cliente quer um
**marcador de cor por caixa** para bater o olho e identificar.

## Objetivo

Permitir que cada caixa tenha uma **cor configurável** (uma só por caixa), que aparece:

1. Na **lista de conversas**: o nome da caixa vira uma etiqueta colorida (texto na cor da caixa
   sobre um fundo bem claro da mesma cor).
2. Na **conversa aberta**: os **balões enviados** ficam na cor da caixa (texto branco). Os balões
   recebidos continuam cinza, sem mudança.

Caixa **sem cor definida** mantém o visual atual (balão azul, nome da caixa no estilo padrão). A
cor é opcional.

## Decisões de design (fechadas no brainstorming)

- **Uma cor por caixa**, usada nos dois lugares (etiqueta + balão). Não há cores separadas.
- **Paleta fixa de ~10 cores prontas** (sem seletor hexadecimal livre). Cada cor da paleta é
  escura o bastante para funcionar nos dois usos: texto branco sobre o balão cheio, e o mesmo hex
  como texto sobre um fundo a ~10% de opacidade na etiqueta. Guardamos **um único hex**; o tom
  claro da etiqueta é derivado no CSS (opacidade / `color-mix`), sem segundo valor.
- **Configuração dentro da caixa**: seção nova na página de configurações da caixa de entrada.
- **Fora de escopo:** tornar configurável a **cor da marca global** (o `n.brand`/`woot` forçado
  para vinho em `theme/colors.js`). É um recurso maior, de natureza diferente (global da conta,
  exige refatorar tokens do Tailwind para variáveis CSS em runtime). Fica como projeto futuro
  separado.

## Arquitetura

### Armazenamento (backend)

- Coluna nova `custom_color` em `inboxes` (string, nullable), guardando um hex da paleta.
  - Migration **nossa e idempotente** (`unless column_exists?(:inboxes, :custom_color)`),
    seguindo o padrão do fork.
- Validação no modelo `Inbox`: quando presente, `custom_color` tem de ser um dos hex da paleta
  (lista canônica no backend). Valor inválido → erro de validação (422 no controller).

### Serialização e params (edições mínimas no upstream — registrar em "Mudanças nossas")

Não há campo jsonb genérico já serializado na `Inbox` para reaproveitar, então o atributo precisa
descer e subir por arquivos do upstream, com a menor pegada possível:

- `app/views/api/v1/models/_inbox.json.jbuilder`: 1 linha — `json.custom_color resource.custom_color`.
- `app/controllers/api/v1/accounts/inboxes_controller.rb`: permitir `custom_color` nos params.

### Paleta (compartilhada)

- Lista canônica dos hex da paleta definida **uma vez** e usada em dois lugares:
  - Backend: validação do `custom_color` (arquivo nosso, ex.: `app/models/concerns/custom/...`
    ou constante em lib `custom/`).
  - Frontend: render do seletor e checagem. Constante JS própria do fork.
- Manter as duas listas em sincronia (mesma ordem/valores). Documentar a fonte única.

### Frontend — configuração

- Componente novo nosso (ex.: `InboxCustomColorPicker.vue`) que mostra a paleta + a opção
  "Sem cor" e grava `custom_color` na caixa via a action de update de inbox já existente.
- Montado na página de configurações da caixa (1 import + 1 tag no arquivo do upstream da aba de
  configurações da inbox). Confirmar no plano qual arquivo/aba exata.

### Frontend — exibição

- **Etiqueta na lista / cabeçalho:** o ícone + nome da caixa são centralizados em
  `app/javascript/dashboard/components-next/Conversation/InboxName.vue`, usado tanto no card da
  lista (`ConversationCardExpanded.vue`) quanto no `ConversationHeader.vue`. Aplicar a cor ali
  cobre os dois lugares. Confirmar no plano se a lista em uso no install do cliente é a de
  `components-next` ou o card antigo (`components/…`); se for o antigo, cobrir também.
- **Balão enviado:** no bubble de `components-next/message`, quando a conversa pertence a uma
  caixa com `custom_color`, pintar o fundo do balão enviado (`isOutgoing`) com a cor e texto
  branco. A caixa da conversa é conhecida no frontend (conversa tem `inbox_id`; o inbox no store
  carrega `custom_color`). Recebidos não mudam.
- Como a cor vem do banco (não é classe estática do Tailwind), aplicar via **variável CSS / estilo
  inline mínimo** com o hex, não por classe utilitária compilada.

### i18n

- Chaves novas ("Cor da caixa", "Sem cor", tooltip/legenda) em **en, pt_BR e es**, nos arquivos
  do overlay do fork (`app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/*.json`). Nunca nos
  locales do upstream.

## Specs

- **Backend**
  - Migration idempotente (roda em banco sem a coluna; não quebra se já existir).
  - Serializer inclui `custom_color`.
  - Controller aceita e persiste `custom_color`; valor fora da paleta → 422.
  - Validação de `custom_color` no modelo (hex da paleta; nil permitido).
- **Frontend**
  - Seletor grava a cor escolhida e "Sem cor" limpa.
  - `InboxName` reflete a cor (e cai no estilo padrão quando a caixa não tem cor).
  - Balão enviado reflete a cor; sem cor → comportamento atual (azul).

## Mudanças nossas em arquivos do upstream (a registrar no `.claude/CLAUDE.md` ao implementar)

- `app/views/api/v1/models/_inbox.json.jbuilder` — serializa `custom_color`.
- `app/controllers/api/v1/accounts/inboxes_controller.rb` — permite `custom_color`.
- Arquivo da aba de configurações da inbox — monta o seletor de cor.
- `InboxName.vue` (e, se aplicável, o card antigo) — aplica a cor na etiqueta.
- Bubble de `components-next/message` — aplica a cor no balão enviado.

> Cada edição deve ser mínima e localizada; preferir colocar a lógica em componentes/arquivos
> nossos e só "plugar" nos arquivos do upstream.
