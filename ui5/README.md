# Front-end Fiori – Pedidos de Compras

Quatro aplicações **SAP Fiori Elements (OData V4, List Report + Object Page)** geradas com o
**SAP Fiori tools** (Application Generator, template `@sap/generator-fiori:lrop`), uma para cada
serviço RAP do pacote `ZAVBS_PEDIDOS_COMPRAS`. Cada app é um **projeto isolado**: tem o próprio
`package.json`, `node_modules`, `ui5*.yaml` e é instalada, executada e publicada separadamente.

A UI é orientada a anotações. Colunas, filtros, seções, ações e criticidade vêm das Metadata
Extensions (`*.ddlx.cds`) do backend. Nas apps ficam só o `manifest.json` (rotas, páginas,
tabelas, tile) e a configuração das ferramentas.

| App                | Pasta              | `sap.app.id`     | Serviço (binding OData V4)  | Tile (inbound)           | BSP / pacote                         |
| ------------------ | ------------------ | ---------------- | --------------------------- | ------------------------ | ------------------------------------ |
| Gestão de Clientes | `gestao-clientes/` | `gestaoclientes` | `ZUI_PC_CLIENTES_O4`        | `ZPCCliente-manage`      | `ZPC_CLIENTES` / `ZAVBS_PC_CLIENTES` |
| Gestão de Estoque  | `gestao-estoque/`  | `gestaoestoque`  | `ZUI_PC_ESTOQUE_O4`         | `ZPCItemEstoque-manage`  | `ZPC_ESTOQUE` / `ZAVBS_PC_ESTOQUE`   |
| Pedidos de Compras | `pedidos-compras/` | `pedidoscompras` | `ZUI_PC_PEDIDOS_COMPRAS_O4` | `ZPCPedidoCompra-manage` | `ZPC_PEDIDOS` / `ZAVBS_PC_PEDIDOS`   |
| Gestão de Reembolsos | `gestao-reembolsos/` | `gestaoreembolsos` | `ZUI_PC_REEMBOLSOS_O4` | `ZPCReembolso-manage` | `ZPC_REEMBOLSOS` / `ZAVBS_PC_PEDIDOS` |

## Estrutura de cada app

```
<app>/
├── package.json          scripts start / start-mock / build / lint / int-test / deploy
├── ui5.yaml              servidor local: proxy /sap → BTP (reentranceTicket), UI5 da CDN
├── ui5-local.yaml        igual, com UI5 local
├── ui5-mock.yaml         mock server com o metadata de localService/
├── ui5-deploy.yaml       deploy no ABAP Repository (BSP + IAM App)
└── webapp/
    ├── manifest.json     descriptor v2: serviço, rotas LR → OP → sub-OP, tabelas, inbound do tile
    ├── Component.js      sap/fe/core/AppComponent
    ├── annotations/      anotações locais (só pedidos usa: mapeamento CpfCliente → Cpf)
    ├── i18n/             textos pt-BR (idioma padrão)
    ├── localService/     metadata do serviço, para o mock
    └── test/integration/ testes OPA5 gerados
```

## Páginas

| App      | List Report                                                                                              | Object Page                                                                                                                                                  | Sub-páginas                               |
| -------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------- |
| Clientes | `Cliente`                                                                                                | Cliente, com a tabela de endereços e a ação **Definir endereço principal**                                                                                   | `Endereco`                                |
| Estoque  | `Item`                                                                                                   | Item                                                                                                                                                         | —                                         |
| Pedidos  | `Pedido`, com as ações Simular pagamento / Aprovar / Cancelar (o Save do rascunho registra o pedido e reserva o estoque) | Pedido. Itens criados na própria tabela (*inline*) só no rascunho; Pagamento e Histórico do cliente como formulário (composição 0..1) | `ItemPedido`, `ItemSnapshot` |
| Reembolsos | `Reembolso`, com as ações Aprovar reembolso / Rejeitar reembolso (lista própria, sem criar/editar/excluir) | Reembolso (identificação, motivos e datas da solicitação e da decisão) | — |

- As ações com parâmetros abrem o diálogo a partir das abstract entities `ZPC_A_PAGAMENTO_INPUT`,
  `ZPC_A_CANCELAMENTO_INPUT` e `ZPC_A_REEMB_DECISAO_INPUT`. Os botões da app de Reembolsos só ficam
  ativos com a solicitação `PENDENTE` (feature control do backend); rejeitar exige motivo.
- O **CEP** do endereço é um campo padrão: o value help `ZC_PC_CEP_VH` sugere CEPs já cadastrados e
  a determination `PreencherEnderecoViaCep`, com side effects, preenche o restante do endereço.

### Navegação entre apps

As projeções do pedido marcam `ClienteUUID`/`NomeCliente` com o semantic object `ZPCCliente` e o
item com `ZPCItemEstoque`. A app de destino abre direto a Object Page quando recebe a chave
semântica: `Cpf` no Cliente (o `annotation.xml` de pedidos mapeia `CpfCliente` → `Cpf`) e `Sku` no
Item. A navegação funciona no launchpad do sistema, para quem tiver as duas apps nas suas roles.

## Apps analíticos (Analytical List Page e Overview Page)

Vinte e um apps adicionais, somente leitura, sobre o serviço **`ZUI_PC_ANALITICO`** (binding
`ZUI_PC_ANALITICO_O4`, OData V4 – UI): 20 ALPs (um por cenário de análise) e o Painel de Compras (OVP).
Eles não alteram os apps de gestão: leem views CDS analíticas próprias (`ZI_PC_*_CUBE` →
`ZC_PC_*_ANALISE`), com `@Aggregation.default` nas medidas e `@OData.applySupportedForAggregation: #FULL`
(para o servidor aceitar `$apply=groupby/aggregate`). Gráficos, filtros e KPIs vêm das metadata
extensions `ZC_PC_*_ANALISE`: cada cenário é um `UI.Chart` + `UI.PresentationVariant` com `qualifier`.

| Domínio | App (pasta) | Cenário (qualifier) | BSP |
| --- | --- | --- | --- |
| Pedidos | `analise-pedidos` | Valor por status (`ValorPorStatus`) | `ZPC_ANL_PED` |
| Pedidos | `analise-pedidos-mes` | Pedidos por mês (`PedidosPorMes`) | `ZPC_ANL_PMES` |
| Pedidos | `analise-pedidos-uf` | Valor por UF (`ValorPorUf`) | `ZPC_ANL_PUF` |
| Pedidos | `analise-pedidos-pagamento` | Pedidos por forma de pagamento (`PedidosPorPagamento`) | `ZPC_ANL_PPAG` |
| Pedidos | `analise-ticket-medio` | Ticket médio por status (`TicketMedioPorStatus`) | `ZPC_ANL_TKT` |
| Clientes | `analise-clientes` | Clientes por gênero (`ClientesPorGenero`) | `ZPC_ANL_CLI` |
| Clientes | `analise-clientes-uf` | Clientes por UF (`ClientesPorUf`) | `ZPC_ANL_CUF` |
| Clientes | `analise-clientes-score` | Clientes por faixa de score (`ClientesPorFaixaScore`) | `ZPC_ANL_CSC` |
| Clientes | `analise-cadastros-mes` | Cadastros por mês (`CadastrosPorMes`) | `ZPC_ANL_CMES` |
| Clientes | `analise-score-uf` | Score médio por UF (`ScoreMedioPorUf`) | `ZPC_ANL_SUF` |
| Estoque | `analise-estoque` | Disponível e reservado por categoria (`DisponivelPorCategoria`) | `ZPC_ANL_EST` |
| Estoque | `analise-itens-situacao` | Itens por situação (`ItensPorSituacao`) | `ZPC_ANL_ISIT` |
| Estoque | `analise-valor-estoque` | Valor em estoque por categoria (`ValorEstoquePorCategoria`) | `ZPC_ANL_VEST` |
| Estoque | `analise-itens-reservados` | Itens mais reservados (`ItensMaisReservados`) | `ZPC_ANL_IRES` |
| Estoque | `analise-itens-categoria` | Itens por categoria (`ItensPorCategoria`) | `ZPC_ANL_ICAT` |
| Reembolsos | `analise-reembolsos` | Valor por status (`ValorPorStatus`) | `ZPC_ANL_REE` |
| Reembolsos | `analise-reemb-qtde` | Quantidade por status (`ReembQtdePorStatus`) | `ZPC_ANL_RQTD` |
| Reembolsos | `analise-reemb-mes` | Valor por mês (`ReembValorPorMes`) | `ZPC_ANL_RMES` |
| Reembolsos | `analise-reemb-uf` | Valor por UF (`ReembValorPorUf`) | `ZPC_ANL_RUF` |
| Reembolsos | `analise-reemb-motivo` | Reembolsos por motivo (`ReembPorMotivo`) | `ZPC_ANL_RMOT` |
| Painel | `painel-compras` (OVP) | 20 cards de gráfico + 3 listas + atalhos | `ZPC_PAINEL` |

Pacotes: Pedidos `ZAVBS_PC_PEDIDOS`, Clientes `ZAVBS_PC_CLIENTES`, Estoque `ZAVBS_PC_ESTOQUE`,
Reembolsos `ZAVBS_PC_REEMBOLSOS`, Painel `ZAVBS_PC_COMMON`. O tile de cada ALP usa o intent
`ZPCAn…-display`, definido no `manifest.json` do app.

- **ALPs só com gráfico.** Cada um é um List Report V4 com `views.paths.primary` apontando para a
  `UI.PresentationVariant` (que tem apenas o `UI.Chart`), sem `secondary` e com
  `defaultPath: "primary"`: não há tabela nem Object Page. Os filtros vêm de `UI.SelectionFields`.
  Cada app mostra um único gráfico; para outro cenário do mesmo domínio, abra o app correspondente.
- **Painel de Compras** (OData V4, cards `sap.ovp.cards.v4.*`): 20 cards de gráfico (um por
  cenário), 3 listas de ação (pedidos aguardando aprovação, reembolsos pendentes, estoque crítico,
  filtradas por `UI.SelectionVariant` no `annotation.xml` local) e um card de atalhos que abre os
  4 apps de gestão pelos intents `ZPC*-manage`. Cada card tem `UI.Identification` para navegar.
  A OVP não tem gráfico de barras horizontais, então o estoque usa um `UI.Chart` de colunas só no
  `annotation.xml` local.
- Os gráficos dependem de agregação no servidor (`$apply`). Se o gráfico vier vazio ou com erro de
  `groupby`, teste a URL
  `…/zui_pc_analitico/0001/ClienteAnalise?$apply=groupby((Genero),aggregate(QtdeClientes))`.
- Para a OVP e os ALPs mostrarem dados é preciso carregar os dados de demonstração
  (`ZCL_PC_SETUP`).

## Executar localmente

```bash
cd ui5/<app>
npm install
npm start          # launchpad local (sandbox) com dados reais
npm run start-mock # dados de mock, sem backend
```

O proxy (`fiori-tools-proxy`) encaminha `/sap` para o sistema BTP ABAP com
`authenticationType: reentranceTicket`: na primeira chamada, o navegador abre o login do BTP.

## Validar

```bash
npm run lint       # ESLint (@sap-ux/eslint-plugin-fiori-tools)
npm run build      # ui5 build (dist/)
npm run int-test   # testes OPA5 gerados, com mock server
```

## Deploy no SAP BTP ABAP Environment

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # cria/atualiza a BSP ZPC_* e o IAM App ZPC_*_UI5R no pacote ZAVBS_PC_*
```

No trial, os pacotes do software component `ZLOCAL` não usam transporte. Em sistemas com
transporte, preencha `transport:` em `ui5-deploy.yaml`.

Depois do deploy, cada app abre direto no ABAP (login pelo SAP ID):

| App | URL |
| --- | --- |
| Gestão de Clientes | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_clientes/index.html` |
| Gestão de Estoque  | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_estoque/index.html` |
| Pedidos de Compras | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_pedidos/index.html` |

### Acesso pelo SAP Build Work Zone, standard edition

No ABAP trial, o usuário não tem os apps *Maintain Business Roles* e *Manage Launchpad Spaces*,
então os tiles não podem ser publicados no launchpad do próprio ABAP. O ponto de entrada é o
**SAP Build Work Zone**, com **tiles do tipo URL** que abrem as apps hospedadas no ABAP (tabela
acima) em uma nova aba. Cada app funciona isoladamente; a navegação entre apps (pedido → cliente /
item) depende do shell do launchpad e não funciona nesse modo.

No Site Manager: *Content Manager* → **+ New → App** → aba *Properties*: título, **Open App: In a
new tab** e a URL; aba *Navigation*: um intent próprio (ex.: `ZPCClienteWeb` / `display`); aba
*Visualization*: subtítulo e ícone. Depois, atribuir as quatro apps a um grupo e ao role
**Everyone**, e abrir o site.

> **Por que não publicar as apps no Cloud Foundry (HTML5 repo + managed approuter)?**
> Foi testado e descartado. O Work Zone da subconta trial só aceita login pelo IAS
> ("business users", origin `sap.custom`), e o XSUAA emite para esse login um `user_name` que
> não é o e-mail (`nome (business users)`). O ABAP trial é um sistema compartilhado da SAP e só
> reconhece o usuário vindo do SAP ID (`sap.default`, `user_name` = e-mail): com o token do IAS,
> o OData responde 401, inclusive após o `OAuth2UserTokenExchange` da destination. Uma destination
> `OAuth2Password` com o usuário do SAP ID também não é viável quando a conta tem 2FA.
