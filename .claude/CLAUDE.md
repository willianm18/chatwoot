# Chatwoot Custom — fork de fazer-ai/chatwoot

@../AGENTS.md

As diretrizes de desenvolvimento do projeto estão no `AGENTS.md` importado acima (é do upstream; não editar).
Este arquivo é o contexto **deste** fork. Detalhes de infraestrutura e do cliente ficam no `CLAUDE.local.md`
(fora do git, porque este repositório é público).

Responder em pt-BR. Código, comentários e mensagens de commit seguem o padrão do repositório (inglês).

## REGRA PRINCIPAL — branches, merges e releases

Cadeia: `chatwoot/chatwoot` → `fazer-ai/chatwoot` (**upstream**) → `willianm18/chatwoot` (**origin**). Só se escreve
no origin.

- **`main` do origin é o produto**: código da fazer.ai + as nossas mudanças. É dele que sai a imagem de produção.
  Nunca commitar direto no `main`.
- **Toda mudança nossa** em branch própria a partir do `main` (`feat/…`, `fix/…`, `chore/…`), PR no **origin**
  (`gh pr create --repo willianm18/chatwoot`), merge com **squash**.
- **Sincronizar com a fazer.ai** só por release (tag `vX.Y.Z-fazer-ai.N`), numa branch própria, e merge com
  **merge commit — nunca squash** (o squash corta a ancestralidade e o próximo sync vira conflito em tudo):
  ```bash
  git fetch upstream --tags
  git switch -c chore/sync-upstream-<tag> main
  git merge <tag>            # resolver conflitos, rodar os specs do que é nosso
  # PR para main → gh pr merge <n> --merge
  git rev-list --count main..<tag>   # depois do merge: tem que dar 0
  ```
- **Releases nossas**: tag `<tag da fazer.ai>-custom.<N>` (ex.: `v4.18.0-fazer-ai.132-custom.1`), criada a partir do
  `main`. **Cortar a release é o que dispara o build e publica a imagem** `ghcr.io/willianm18/chatwoot` (workflow
  "Publish custom CE docker image"); nunca `workflow_dispatch push=true`. Antes de cortar, rodar a skill
  `release-user-notes` (notas en/pt-BR/es no corpo). Numerar pela tag (`git ls-remote --tags`), nunca por
  `gh release list`; depois conferir que a tag aponta pro commit certo (`git rev-parse <tag>^{commit}`).
- **Dois ambientes, imagem nova SEMPRE em homologação antes de produção.** Há um ambiente de HML e um de PRD
  (domínios/containers no `CLAUDE.local.md`, fora do git). Toda imagem nova sobe primeiro em HML pra teste; só
  depois em PRD. Rollback = reapontar o deploy pra a tag de release anterior (as tags antigas ficam no ghcr; nunca
  apagar).
- **Fluxo completo de entrega:** melhoria em branch `feat/|fix/` → PR no origin → **merge squash** → (quando
  precisar) **sync do fazer.ai** por tag em branch própria, **merge commit (nunca squash)** → **cortar release**
  `…-custom.N` → imagem → **HML** → **PRD**.
- **Nunca** abrir PR, issue ou push na fazer.ai nem no chatwoot sem o usuário pedir. Nunca fazer push nem abrir PR
  no origin sem o usuário pedir.
- Para manter os conflitos raros: código novo em arquivos novos (prefixo `custom`), traduções em arquivos próprios,
  edição em arquivo do upstream só se não houver outro jeito — e registrada em "Mudanças nossas" abaixo.

## O que é

- `willianm18/chatwoot` = fork de [`fazer-ai/chatwoot`](https://github.com/fazer-ai/chatwoot), que por sua vez é fork
  do [`chatwoot/chatwoot`](https://github.com/chatwoot/chatwoot). A fazer.ai acompanha as releases oficiais e soma
  recursos de WhatsApp (conector nativo em Go, grupos, reações, edição, histórico, ligações), chat interno,
  mensagens agendadas etc.
- Objetivo deste fork: o que falta para um atendimento "nativo" de WhatsApp, mantendo o merge do upstream barato.

## Remotes e sincronização

O `AGENTS.md` foi escrito para o repositório da fazer.ai: lá `origin` é `fazer-ai/chatwoot` e `upstream` é
`chatwoot/chatwoot`. **Aqui não**, e as seções "Git Remotes & PRs", "Cutting a release", "Pro repo gotchas" e o
fluxo da skill `sync-fork` não se aplicam como estão.

- `origin` = `willianm18/chatwoot`; `upstream` = `fazer-ai/chatwoot` (branch `main`, tags `vX.Y.Z-fazer-ai.N`).
- `gh repo set-default willianm18/chatwoot` já está feito neste clone. Sem isso o `gh pr create` abre PR no
  repositório pai (fazer-ai). **Nunca abrir PR na fazer.ai nem no chatwoot** sem o usuário pedir.
- Clone parcial (`--filter=blob:none`): blobs antigos baixam sob demanda.
- Sincronização: ver a REGRA PRINCIPAL no topo.
- A skill `.claude/skills/sync-fork` é da fazer.ai (fluxos chatwoot→fazer-ai e CE→Pro). Serve de referência para
  padrões de conflito, mas **não** é o nosso fluxo: o nosso upstream é só `fazer-ai/chatwoot` `main`.

## Regras para manter o merge barato

- Preferir **arquivos novos** a editar arquivos do upstream. Quando precisar editar, mudança mínima e localizada.
  Ver também a REGRA PRINCIPAL no topo.
- Marcar o que é nosso: prefixo/namespace `custom` (ex.: `app/services/custom/…`, `lib/tasks/custom/…`).
- Traduções: seguir "Fork translations" do `AGENTS.md` (nunca editar locale do upstream; en, pt_BR e es sempre).
  Nossas chaves vão em arquivos **nossos** dentro do overlay, ex.:
  `app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/custom.json` e `config/locales/custom.<locale>.yml`,
  para não conflitar com os arquivos da fazer.ai.
- Cada recurso nosso com spec. Migrations novas idempotentes.
- Registrar abaixo, em "Mudanças nossas", todo arquivo do upstream que tivermos editado.

## Licença (importante)

- Fora de `enterprise/`: MIT (Chatwoot Inc. + FAZER.AI LTDA). Manter os avisos de copyright.
- `enterprise/` é licença Chatwoot Enterprise: uso em produção só com assinatura; código derivado pertence à
  Chatwoot Inc. **Nunca copiar nem adaptar código de `enterprise/`** para fora dela. Recurso nosso que dependa do
  que está lá (ex.: ligações de voz) precisa ser escrito do zero.
- Código Pro da fazer.ai (Kanban, chat interno completo) não está aqui e não deve ser reproduzido.

## Backlog (prioridade)

1. **Migration `20250213190934_add_name_to_webhooks` idempotente** (`unless column_exists?(:webhooks, :name)`).
   Ela quebra em banco vindo do Chatwoot oficial, que já criou a coluna em `20251010143218`. Hoje contornamos
   inserindo a versão em `schema_migrations`. Vale abrir issue/PR na fazer.ai também.
2. **Saneamento do histórico importado** (rake task em `lib/tasks/custom/`): ao parear um número que já tinha
   conversas vindas de outro conector (WAHA, via caixa API movida para a nativa), o "Importar conversas antigas"
   duplica mensagens. Regra: casar importada (`content_attributes.imported`) com a já existente pelo mesmo contato
   + direção + horário (±60 s) + texto (ou ambas mídia); na existente, gravar o `source_id` da importada (ganha o ID
   do WhatsApp → reação/resposta citada passam a funcionar nela) e apagar a importada. Importadas sem par ficam,
   mas movidas para uma conversa resolvida de arquivo do contato, fora do atendimento aberto. Mídia do histórico
   chega sem arquivo (`history_media: true`); quando a existente tem o arquivo, ela vence. Modo simulação obrigatório.
3. **Encaminhar mensagem**: ação na mensagem → escolher contato/conversa → enviar pelo conector com a marca
   "Encaminhada" do WhatsApp (na Cloud API não há a marca; reenviar conteúdo).
4. **Nome do agente obrigatório por caixa**: opção na caixa que prefixa `*Nome:*` no servidor (hoje só existe a
   assinatura pessoal, que o agente pode desligar e que não vale para API/automação).
5. **Seção "Grupos"** fixa na barra lateral (hoje feito com pasta/filtro salvo "Tipo de conversa = Grupo").
6. **Pipeline de imagem**: publicar `ghcr.io/willianm18/chatwoot` (pacote privado) a partir de tag/release.
   O fork herdou 21 workflows do upstream; antes de habilitar Actions, desligar o que não é nosso (stale,
   linear sync, codespace, nightly installer...) e deixar só build/test.
7. (Opcional, grande) Ligações de voz sem `enterprise/`.

## Mudanças nossas em arquivos do upstream

- `theme/colors.js` — cor primária da marca trocada para vinho. (1) bloco `woot` (design system antigo)
  remapeado de `blue*` para `ruby*` (importa `ruby`/`rubyDark` do `@radix-ui/colors`); (2) token `n.brand`
  (design system novo, usado em `components-next` via `bg-n-brand`) de `#2781F6` para `#9F1239`. O visível no
  dashboard atual vem do `n.brand`. Reverter = voltar `woot` para `blue*` e `n.brand` para `#2781F6`.
- `app/javascript/dashboard/helper/editorHelper.js` e
  `app/javascript/dashboard/routes/dashboard/settings/profile/MessageSignature.vue` — opção de separador de
  assinatura **"Sem linha em branco"** (`none` → `\n`), além de `blank`/`--`. i18n da chave `NONE` no overlay
  (`fazer-ai/locale/<locale>/custom.json`). Enviado também à fazer.ai como contribuição; quando eles mergearem,
  remover nossa chave do overlay no sync. Reverter = tirar `none` do mapa e a opção da lista.
- **Encaminhar mensagem (WhatsApp nativo)** — Fase 1 (uma mensagem pelo menu de contexto). Edições em arquivos
  do upstream, mínimas:
  - `config/routes.rb` — `resources :forwards, only: [:create]` aninhado na conversa (bloco
    `scope module: :conversations`), com `get :contacts, on: :collection` (busca de contatos escopada à caixa).
  - `app/javascript/dashboard/modules/conversations/components/MessageContextMenu.vue` — emite `forward` e um
    `MenuItem` "Encaminhar" quando `enabledOptions['forward']`.
  - `app/javascript/dashboard/components-next/message/Message.vue` — gate `forward` em
    `contextMenuEnabledOptions` (caixa WhatsApp de sessão + mensagem encaminhável) e render do
    `ForwardWhatsappPanel`.
  O resto é nosso (arquivos novos): `app/services/custom/messages/forward_service.rb`,
  `app/controllers/api/v1/accounts/conversations/forwards_controller.rb`,
  `components-next/message/forward/ForwardWhatsappPanel.vue`,
  `components-next/message/forward/forwardContactSearch.js`, action `forwardMessages` + método
  `forwardableContacts` na store/API, i18n no overlay `fazer-ai/locale/<locale>/conversation.json`.
  Design/plano em `docs/superpowers/`.
  Reverter = tirar a rota, o item do menu, o gate/painel e apagar os arquivos novos.
  Ajustes pós-HML (2026-10-31): (1) `ForwardService#resolve_target_conversation!` reusa a conversa
  existente do contato na caixa via `target_contact.conversations.where(inbox:)` em vez de derivar
  `source_id` do telefone (o 9º dígito BR fazia criar conversa duplicada); (2) busca de contatos
  escopada à caixa de origem (`forwards#contacts` + `forwardContactSearch.js`), só contatos com thread
  naquela caixa — some a ambiguidade de homônimos de outras caixas; (3) `ForwardWhatsappPanel` sem
  `close-on-focus-out="false"` → fecha ao clicar fora/`Esc` (antes travava a conversa pelo scroll-lock).
  Fase 2 — seleção múltipla estilo WhatsApp (2026-10-31): "Encaminhar" no menu **entra no modo de
  seleção** (não abre o painel direto); bolhas encaminháveis ganham checkbox; barra de ação no nível da
  conversa com contagem + Encaminhar + Cancelar (`Esc`); o painel sobe para a conversa e recebe
  `messageIds`/`conversationId` por props (deixou de usar `useMessageContext`). Arquivos novos nossos:
  `components-next/message/forward/useForwardSelection.js`, `isForwardableMessage.js`,
  `ForwardSelectionBar.vue`, `ConversationForwardOverlay.vue`. Edições upstream mínimas adicionais:
  `components-next/message/Message.vue` (handler do `forward` → `start`; checkbox na bolha; gate reusa
  `isForwardableMessage`; painel removido daqui) e
  `routes/dashboard/conversation/ConversationView.vue` (render do `ConversationForwardOverlay`). i18n das
  chaves `FORWARD.SELECTION_COUNT/N_MESSAGES/CANCEL` no overlay. Design em
  `docs/superpowers/specs/2026-10-31-forward-message-phase2-design.md`.
- **Cor por caixa** (`custom_color` em `inboxes`) — cada caixa tem uma cor (paleta fixa de 10) que tinge a
  etiqueta do nome na lista/cabeçalho e os balões enviados. Edições mínimas no upstream:
  - `app/models/inbox.rb` — `include Custom::InboxCustomColor` (concern nosso com a paleta + validação).
  - `app/views/api/v1/models/_inbox.json.jbuilder` — `json.custom_color`.
  - `app/controllers/api/v1/accounts/inboxes_controller.rb` — `:custom_color` em `inbox_attributes`.
  - `routes/dashboard/settings/inbox/Settings.vue` — seletor na aba geral.
  - `components/widgets/InboxName.vue` + `components-next/Conversation/InboxName.vue` — etiqueta tingida.
  - `components-next/message/bubbles/Base.vue` (marcador `agent-bubble`) + `components-next/message/Message.vue`
    (regra CSS) + `routes/dashboard/conversation/ConversationView.vue` (variável CSS `--inbox-send-bubble` no root).
  O resto é nosso: `app/models/concerns/custom/inbox_custom_color.rb`, `dashboard/constants/customInboxColors.js`,
  `dashboard/components/custom/InboxColorPicker.vue`, `routes/dashboard/conversation/inboxBubbleStyle.js`, i18n no
  overlay `fazer-ai/locale/<locale>/inboxMgmt.json`. A paleta é duplicada (concern ↔ const JS): manter em sincronia.
  Reverter = tirar o include/linha/param/bindings e dropar a coluna.

## Gotchas conhecidos do fork

- Primeiro deploy numa base nova falha com `rails hook exited with status 1` (o `post_start` de branding roda antes
  das migrations); redeploy resolve.
- `FRONTEND_URL` precisa ser o domínio público real; com URL errada, áudio e anexos não carregam (mixed content).
- Ligações: rotas e o job `Whatsapp::ConnectorCallReconcileJob` estão em `enterprise/` → imagem `-ee` em **rails e
  sidekiq**, feature `channel_voice` na conta, `WAC_CALLS_UDP_PORT` + porta UDP publicada, `WAC_CALLS_PUBLIC_IP` atrás de NAT.
- Grupos: `WHATSAPP_GROUPS_ENABLED=true` em rails e sidekiq. Cada participante vira contato (LID, sem telefone).
- O nativo grava o telefone como o WhatsApp entrega (celular BR muitas vezes **sem o 9º dígito**) e regrava o do
  contato a cada mensagem. A busca de contato casa as duas formas (`Whatsapp::Session::PhoneMatch`).
- Reação vira `Message` com `content_attributes.is_reaction` e dispara `message_created` no webhook.
- Importação de histórico é silenciosa (sem webhook/notificação); mídia antiga vem sem arquivo.
