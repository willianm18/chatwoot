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
  `main`. É a tag que vai disparar o build da imagem (backlog item 6).
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
    `scope module: :conversations`).
  - `app/javascript/dashboard/modules/conversations/components/MessageContextMenu.vue` — emite `forward` e um
    `MenuItem` "Encaminhar" quando `enabledOptions['forward']`.
  - `app/javascript/dashboard/components-next/message/Message.vue` — gate `forward` em
    `contextMenuEnabledOptions` (caixa WhatsApp de sessão + mensagem encaminhável) e render do
    `ForwardWhatsappPanel`.
  O resto é nosso (arquivos novos): `app/services/custom/messages/forward_service.rb`,
  `app/controllers/api/v1/accounts/conversations/forwards_controller.rb`,
  `components-next/message/forward/ForwardWhatsappPanel.vue`, action `forwardMessages` na store/API, i18n no
  overlay `fazer-ai/locale/<locale>/conversation.json`. Design/plano em `docs/superpowers/`.
  Reverter = tirar a rota, o item do menu, o gate/painel e apagar os arquivos novos.

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
