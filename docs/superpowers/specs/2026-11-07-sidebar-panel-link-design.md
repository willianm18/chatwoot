# Item "Painel" na barra lateral (link externo via `.env`)

**Data:** 2026-11-07
**Status:** aprovado (brainstorming)

## Objetivo

Adicionar um item fixo **"Painel"** na barra lateral do dashboard, **logo abaixo do "Chat
Interno"**, visível para **todos os agentes**, que abre **em nova aba** uma URL externa
configurada por variável de ambiente (`.env`). O item só aparece quando a URL está configurada.

## Contexto do código

- A barra é montada em `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` a partir
  de um array `menuItems` (cada entrada vira um `SidebarGroup`). O item "Chat Interno" é a
  entrada `name: 'InternalChat'`; "Kanban" vem logo depois.
- `SidebarGroup.vue` / `SidebarGroupHeader.vue` só sabem renderizar **rota interna** (`to`,
  via `router-link`/`router.resolve`). Não existe suporte a link externo hoje.
- Variáveis do backend chegam ao frontend pelo `@global_config` (dumpeado em
  `window.globalConfig` em `app/views/layouts/vueapp.html.erb`) e lidas em
  `app/javascript/shared/store/globalConfig.js`. O `dashboard_controller#app_config` já usa
  `GlobalConfigService.load('CHAVE', default)` (padrão `FB_APP_ID`), que lê do DB e cai no
  `.env` quando o DB está vazio.

## Decisão de abordagem

**Abordagem A (escolhida):** ensinar os componentes da barra a abrir link externo via uma
propriedade nova e opcional, e inserir o item "Painel" no `menuItems` logo após o `InternalChat`.
Isso mantém o item **na posição pedida** e com **o mesmo visual** dos demais (ícone, hover, estado
recolhido). Edição no upstream é aditiva e protegida pela propriedade nova → risco de conflito
baixo.

Abordagem B (descartada): componente próprio no rodapé da barra — quase não toca upstream, mas não
fica abaixo do Chat Interno.

## Como a URL chega na tela

1. `app/controllers/dashboard_controller.rb` — no método `app_config`, adicionar
   `PANEL_URL: ENV.fetch('PANEL_URL', '')`. Leitura **direta do `.env`** (como o `FRONTEND_URL` no
   `vueapp.html.erb`), que mescla a chave no `@global_config` → `window.globalConfig`.
2. `app/javascript/shared/store/globalConfig.js` — ler `PANEL_URL: panelURL` do
   `window.globalConfig` e expor no `state` como `panelURL`.

> **Não usar `GlobalConfigService.load` nem `config/installation_config.yml` aqui.** Semear um
> registro vazio no `InstallationConfig` sombreia o env var: `GlobalConfigService.load` lê o banco,
> e `first_or_create!` não atualiza o registro existente, então o valor do `.env` nunca é lido e o
> item nunca aparece. Leitura direta de `ENV` é imune a isso (bug pego em HML, corrigido em `custom.7`).

`.env` do deploy (HML e PRD) recebe `PANEL_URL=https://...`. A URL do painel é passada pelo usuário
no deploy; não é fixada no código.

## Suporte a link externo na barra (upstream, aditivo)

Propriedade nova nos componentes: `href` (string, URL externa) + `target` (default `_blank`).
Regra: quando `href` está presente, o item vira uma âncora externa; quando ausente, comportamento
atual inalterado.

- `SidebarGroup.vue`
  - Novos props: `href: { type: String, default: null }`, `target: { type: String, default: '_blank' }`.
  - Um item com `href` nunca tem `children` nem `to`; `isActive`/`hasActiveChild` ficam `false`.
  - **Estado recolhido** (bloco `isCollapsed`): quando `href`, renderizar
    `<a :href target rel="noopener noreferrer">` em vez do `router-link`/`button`, mantendo as
    mesmas classes e o `:title="label"`.
  - **Estado expandido**: passar `href`/`target` para o `SidebarGroupHeader`.
- `SidebarGroupHeader.vue`
  - Novos props: `href`, `target`.
  - Quando `href`, renderizar `<a :href target rel="noopener noreferrer">` (sem `@click`
    `preventDefault`, deixando o navegador abrir a nova aba) em vez de resolver rota interna.
    Sem badge/contador, sem chevron (não é expansível).

Manter as classes/estilo idênticos aos itens normais para não destoar.

## Item no menu

Em `Sidebar.vue`, dentro do `menuItems`, inserir logo após a entrada `InternalChat`, **apenas
quando `panelURL` estiver presente**:

```js
...(panelURL.value
  ? [{
      name: 'Panel',
      label: t('SIDEBAR.PANEL'),
      icon: 'i-lucide-layout-dashboard',
      href: panelURL.value,
    }]
  : []),
```

`panelURL` vem de `useMapGetter('globalConfig/get')` (ou getter dedicado) lido do store
`globalConfig`.

## i18n

Chave nova `SIDEBAR.PANEL` = "Painel" (pt_BR) / "Panel" (en) / "Panel" (es), no overlay do fork:
`app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/sidebar.json` (arquivo nomeado conforme o
namespace upstream `sidebar.json`). As três línguas são obrigatórias.

## Fora de escopo (YAGNI)

- Abrir embutido em iframe (foi descartado — abre em nova aba).
- Permissão por função (todos os agentes veem).
- Configuração por conta/por caixa (é global, via `.env`).

## Testes

- **globalConfig.js**: spec garantindo que `panelURL` é lido de `window.globalConfig.PANEL_URL`.
- **Sidebar**: spec/teste de componente garantindo que o item "Painel" aparece quando `panelURL`
  está setado e some quando vazio, e que renderiza uma âncora com `href`/`target="_blank"`.
- **SidebarGroupHeader**: renderiza `<a href target rel>` quando `href` presente; mantém rota
  interna quando ausente.

## Arquivos tocados

Upstream (aditivo, registrar em `.claude/CLAUDE.md` → "Mudanças nossas"):
- `app/controllers/dashboard_controller.rb`
- `app/javascript/shared/store/globalConfig.js`
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
- `app/javascript/dashboard/components-next/sidebar/SidebarGroup.vue`
- `app/javascript/dashboard/components-next/sidebar/SidebarGroupHeader.vue`

Nosso:
- `app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/settings.json` (chave `SIDEBAR.PANEL`; en, pt_BR, es)
- `.env.example` — documentar `PANEL_URL`
