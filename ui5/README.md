# Front-end Fiori – Pedidos de Compras

Quatro aplicações **SAP Fiori Elements (OData V4, List Report + Object Page)** geradas com o
**SAP Fiori tools** (Application Generator, template `@sap/generator-fiori:lrop`), uma para cada
serviço RAP do pacote `ZAVBS_PEDIDOS_COMPRAS`. Cada app é um **projeto isolado**: tem o próprio
`package.json`, `node_modules`, `ui5*.yaml` e é instalada, executada e publicada separadamente.
Além delas, `analise-compras/` é um app freestyle com todas as análises (veja
[App de análises](#app-de-análises-freestyle)) e `loja-ecommerce/` é a loja virtual freestyle com os
produtos do estoque (veja o [README dela](loja-ecommerce/README.md)).

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

Os campos abaixo são marcados no backend com `@Consumption.semanticObject` e viram links (smart
links) para a app de destino:

| Origem | Campos | Semantic object | Destino |
| --- | --- | --- | --- |
| Pedido (`ZC_PC_PEDIDO_APP`) | Cliente (`ClienteUUID`/`NomeCliente`), CPF (`CpfCliente`) | `ZPCCliente` | Gestão de Clientes |
| Item do pedido (`ZC_PC_ITEM_PEDIDO_APP`) | Item (`ItemUUID`/`NomeItem`), SKU (`Sku`) | `ZPCItemEstoque` | Gestão de Estoque |
| Snapshot do cliente (`ZC_PC_PED_CLI_SNAP_APP`) | Nome, CPF | `ZPCCliente` | Gestão de Clientes |
| Snapshot dos itens (`ZC_PC_PED_ITEM_SNAP_APP`) | Item (nome), SKU | `ZPCItemEstoque` | Gestão de Estoque |
| Reembolso (`ZC_PC_REEMBOLSO_APP`) | Pedido (`PedidoUUID`/`NumeroPedido`) | `ZPCPedidoCompra` | Pedidos de Compras |
| Reembolso (`ZC_PC_REEMBOLSO_APP`) | Cliente (`ClienteUUID`/`NomeCliente`), CPF (`CpfCliente`) | `ZPCCliente` | Gestão de Clientes |

No reembolso, o Pedido é um link direto (`#WITH_INTENT_BASED_NAVIGATION`, ação `manage`): o clique
abre a Object Page do pedido, sem o popover dos demais links.

A app de destino abre direto a Object Page quando recebe a chave técnica (`ClienteUUID`,
`ItemUUID`, `PedidoUUID`) ou a semântica (`Cpf`, `Sku`, `NumeroPedido`). No pedido e no reembolso o
CPF chama `CpfCliente`; o backend o mapeia para `Cpf` com `@Consumption.semanticObjectMapping` (o
`annotation.xml` de pedidos repete esse mapeamento). A navegação funciona no launchpad do sistema,
para quem tiver as apps de origem e de destino nas suas roles.

## App de análises (freestyle)

`analise-compras/` é um app **SAPUI5 freestyle** (OData V4, somente leitura) que reúne todas as
análises num único projeto. Ele substitui os 20 apps ALP (`analise-*`) e o Painel de Compras (OVP)
que existiam antes. Lê o serviço **`ZUI_PC_ANALITICO`** (binding `ZUI_PC_ANALITICO_O4`), cujas views
CDS analíticas (`ZI_PC_*_CUBE` → `ZC_PC_*_ANALISE`) têm `@Aggregation.default` nas medidas e
`@OData.applySupportedForAggregation: #FULL`, o que permite `$apply=groupby/aggregate` no servidor.

| App | Pasta | `sap.app.id` | Serviço | Tile (inbound) | BSP / pacote |
| --- | --- | --- | --- | --- | --- |
| Análises de Compras | `analise-compras/` | `analisecompras` | `ZUI_PC_ANALITICO_O4` | `ZPCAnalise-display` | `ZPC_ANALISE` / `ZAVBS_PC_COMMON` |

- **Painel** (`#/painel/<domínio>`): um domínio por vez (Pedidos, Clientes, Estoque, Reembolsos), com
  barra de filtros, indicadores (KPIs) e os 5 gráficos do domínio, num total de 20 cenários.
- **Detalhe** (`#/analise/<cenário>`, clicando no título do card): gráfico grande com troca do tipo
  (colunas, barras, linha, rosca) e tabela com os valores, % do total e linha de total.
- Os **filtros** (os mesmos `UI.SelectionFields` do serviço) valem para os KPIs e para todos os
  gráficos do domínio e continuam aplicados ao abrir um detalhe e ao voltar. As opções vêm do
  próprio serviço (`groupby` do campo).
- **Abrir gestão** abre o app de gestão do domínio: navegação semântica (`ZPC*-manage`) no
  launchpad; fora dele, a BSP irmã (`../zpc_clientes/index.html` etc.) em outra aba.
- Em telas estreitas (< 1024 px) o seletor de domínio vira uma lista suspensa.

| Domínio | Entity set | Cenários (id) |
| --- | --- | --- |
| Pedidos | `PedidoAnalise` | `PedValorPorStatus`, `PedPorMes`, `PedValorPorUf`, `PedPorPagamento`, `PedTicketMedio` |
| Clientes | `ClienteAnalise` | `CliPorGenero`, `CliPorUf`, `CliPorFaixaScore`, `CliCadastrosPorMes`, `CliScorePorUf` |
| Estoque | `ItemAnalise` | `EstDisponivelPorCategoria`, `EstItensPorSituacao`, `EstValorPorCategoria`, `EstMaisReservados` (top 10), `EstItensPorCategoria` |
| Reembolsos | `ReembolsoAnalise` | `ReeValorPorStatus`, `ReeQtdePorStatus`, `ReeValorPorMes`, `ReeValorPorUf`, `ReePorMotivo` |

### Estrutura

```
analise-compras/webapp/
├── Component.js           estado compartilhado (domínio e filtros), serviço e roteamento
├── manifest.json          rotas "" / painel/{domain} / analise/{scenario}, modelo OData V4, tile
├── model/Scenarios.js     catálogo: domínios, filtros, KPIs e os 20 cenários (dimensão, medidas, gráfico)
├── model/AnalyticsQuery.js monta o $apply (descritores) e molda as linhas; sem dependência de UI
├── service/AnalyticsService.js  ODataListBinding + $$aggregation (filter/groupby/aggregate)
├── control/AnalysisChart.js     VizFrame (sap.viz) configurado por dimensão, medidas e tipo
├── control/FilterBar.js         filtros do domínio (lista, sim/não, texto)
├── controller/ view/            Dashboard e Detail
├── i18n/i18n.properties         textos pt-BR (cenários, medidas, dimensões)
├── localService/mainService/    metadata.xml e data/*.json (dados de demonstração do start-mock)
└── test/                        suíte QUnit (Test Starter): catálogo e consultas
```

Para **incluir um cenário**, acrescente uma entrada em `model/Scenarios.js` e os textos
`<id>.title` / `<id>.sub` no `i18n.properties` (o teste do catálogo falha se faltar alguma chave).

> [!NOTE]
> As medidas usam a agregação padrão do backend (no OData, *custom aggregates*), por isso o `$apply`
> é `aggregate(Medida)` sem método. Teste a URL
> `…/zui_pc_analitico/0001/ClienteAnalise?$apply=groupby((Genero),aggregate(QtdeClientes))` se um
> gráfico vier vazio ou com erro de `groupby`. O mock server (`start-mock`) soma `ValorMedio` e
> `ScoreMedio`, em vez de tirar a média como o backend: use-o só para a interface.
> Para ter dados no sistema, carregue os dados de demonstração (`ZCL_PC_SETUP`).

## Executar localmente

```bash
cd ui5/<app>
npm install
npm start          # launchpad local (sandbox) com dados reais
npm run start-mock # dados de mock, sem backend
```

Em `analise-compras` e `loja-ecommerce`, a suíte QUnit abre com `npm run unit-test`.

O proxy (`fiori-tools-proxy`) encaminha `/sap` para o sistema BTP ABAP com
`authenticationType: reentranceTicket`: na primeira chamada, o navegador abre o login do BTP.

## Validar

```bash
npm run lint       # ESLint (@sap-ux/eslint-plugin-fiori-tools)
npm run build      # ui5 build (dist/)
npm run int-test   # testes OPA5 gerados, com mock server (apps Fiori Elements)
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
| Gestão de Reembolsos | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_reembolsos/index.html` |
| Análises de Compras | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_analise/index.html` |
| Loja Virtual | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_loja/index.html` |

### Acesso pelo SAP Build Work Zone, standard edition

No ABAP trial, o usuário não tem os apps *Maintain Business Roles* e *Manage Launchpad Spaces*,
então os tiles não podem ser publicados no launchpad do próprio ABAP. O ponto de entrada é o
**SAP Build Work Zone**, com **tiles do tipo URL** que abrem as apps hospedadas no ABAP (tabela
acima) em uma nova aba. Cada app funciona isoladamente; a navegação entre apps (pedido → cliente /
item) depende do shell do launchpad e não funciona nesse modo.

No Site Manager: *Content Manager* → **+ New → App** → aba *Properties*: título, **Open App: In a
new tab** e a URL; aba *Navigation*: um intent próprio (ex.: `ZPCClienteWeb` / `display`); aba
*Visualization*: subtítulo e ícone. Depois, atribuir as apps (as quatro de gestão e a de análises) a um grupo e ao role
**Everyone**, e abrir o site.

> **Por que não publicar as apps no Cloud Foundry (HTML5 repo + managed approuter)?**
> Foi testado e descartado. O Work Zone da subconta trial só aceita login pelo IAS
> ("business users", origin `sap.custom`), e o XSUAA emite para esse login um `user_name` que
> não é o e-mail (`nome (business users)`). O ABAP trial é um sistema compartilhado da SAP e só
> reconhece o usuário vindo do SAP ID (`sap.default`, `user_name` = e-mail): com o token do IAS,
> o OData responde 401, inclusive após o `OAuth2UserTokenExchange` da destination. Uma destination
> `OAuth2Password` com o usuário do SAP ID também não é viável quando a conta tem 2FA.
