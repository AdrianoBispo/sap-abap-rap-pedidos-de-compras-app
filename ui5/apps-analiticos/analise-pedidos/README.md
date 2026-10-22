# Análise de Pedidos de Compras

Painel somente leitura com indicadores e gráficos dos pedidos de compras: valores por status, por mês e por
UF, situação dos pagamentos e ticket médio.

| | |
| --- | --- |
| Tipo | SAPUI5 freestyle (OData V4, somente leitura, gráficos `sap.viz`) |
| `sap.app.id` | `analisepedidos` |
| Serviço | `ZUI_PC_ANALITICO` (binding OData V4 `ZUI_PC_ANALITICO_O4`) |
| Entity set | `PedidoAnalise` (`ZI_PC_PEDIDO_CUBE` → `ZC_PC_PEDIDO_ANALISE`) |
| Tile (inbound) | `ZPCAnalisePedido-display` — "Análise de Pedidos de Compras" / "Valores, status e pagamentos" |
| BSP / pacote | `ZPC_ANL_PEDIDOS` / `ZAVBS_PC_PEDIDOS` |
| SAPUI5 mínimo | 1.136.0 |

## Telas

| Página | Rota | Conteúdo |
| --- | --- | --- |
| Painel | `#/` | Barra de filtros, indicadores e os 5 gráficos; o título de cada card abre o detalhe |
| Detalhe | `#/analise/<cenário>` | Gráfico grande com troca do tipo (colunas, barras, linha, rosca) e tabela com valores, % do total e linha de total |

<p align="center">
  <img src="../../../assets/telas/analises/pedidos.png" alt="Painel da Análise de Pedidos de Compras" width="700">
</p>

## Filtros e indicadores

| Filtros | Indicadores (KPIs) |
| --- | --- |
| Status do pedido, status do pagamento, UF e mês de criação (listas com os valores do próprio serviço) | Valor total, pedidos e ticket médio |

Os filtros valem para os indicadores e para todos os gráficos, e continuam aplicados ao abrir um detalhe e ao
voltar. A UF é a do endereço principal do cliente.

## Cenários

| Id | Título | Dimensão | Medida | Gráfico | Ordem |
| --- | --- | --- | --- | --- | --- |
| `PedValorPorStatus` | Valor por status do pedido | `StatusPedido` | `ValorTotal` | Colunas | Maior valor |
| `PedPorMes` | Pedidos por mês | `MesCriacao` | `QtdePedidos` | Colunas | Mês |
| `PedValorPorUf` | Valor dos pedidos por UF | `Uf` | `ValorTotal` | Colunas | Maior valor |
| `PedPorPagamento` | Pedidos por status do pagamento | `StatusPagamento` | `QtdePedidos` | Rosca | Maior valor |
| `PedTicketMedio` | Ticket médio por status do pedido | `StatusPedido` | `ValorMedio` | Colunas | Maior valor |

Cada gráfico é uma consulta agregada no servidor. Exemplo do primeiro cenário (medidas monetárias agrupam
também por `Currency`):

```
PedidoAnalise?$apply=groupby((StatusPedido,StatusPedidoTexto,Currency),aggregate(ValorTotal))
```

As medidas usam a agregação padrão do backend (`@Aggregation.default`), por isso o `aggregate` não informa o
método. Se um gráfico vier vazio ou com erro de `groupby`, teste a URL acima no navegador.

## Navegação

- **Abrir gestão** abre a app Pedidos de Compras: pelo intent `ZPCPedidoCompra-manage` no launchpad; fora
  dele, pela BSP irmã (`../zpc_pedidos/index.html`) em outra aba.
- Um hash desconhecido (por exemplo, um link antigo `#/painel/<domínio>` do app único de análises) volta ao
  painel.

## Estrutura

```
analise-pedidos/
├── package.json            scripts (start, start-mock, build, lint, unit-test, deploy)
├── ui5.yaml / ui5-local.yaml / ui5-mock.yaml / ui5-deploy.yaml
└── webapp/
    ├── manifest.json       rotas "" e analise/{scenario}, modelo OData V4, inbound do tile
    ├── Component.js        estado compartilhado (filtros), serviço e roteamento
    ├── model/Scenarios.js  catálogo do domínio: entity set, filtros, KPIs e os 5 cenários
    ├── model/AnalyticsQuery.js     monta o $apply e molda as linhas (sem dependência de UI)
    ├── model/formatter.js  formatação das medidas (inteiro, decimal, moeda) e do % do total
    ├── service/AnalyticsService.js ODataListBinding + $$aggregation
    ├── control/            AnalysisChart (VizFrame) e FilterBar
    ├── controller/ view/   App, Dashboard (painel) e Detail
    ├── css/style.css
    ├── i18n/i18n.properties        textos pt-BR (cenários, medidas, dimensões)
    ├── localService/mainService/   metadata.xml e data/PedidoAnalise.json (dados de demonstração)
    └── test/               suíte QUnit: unit/model/Scenarios e unit/model/AnalyticsQuery
```

**Incluir um cenário**: acrescente uma entrada `sc(...)` em `model/Scenarios.js` e os textos `<id>.title` e
`<id>.sub` no `i18n.properties` (o teste do catálogo falha se faltar alguma chave). O motor (`AnalyticsQuery`,
`AnalyticsService`, `control/`, `controller/`, `view/`) é igual nos quatro apps de análise, a menos do
namespace: uma correção nele deve ser repetida nos outros três.

## Executar

```bash
npm install
npm start           # launchpad de preview com dados reais (proxy /sap → sistema ABAP)
npm run start-mock  # dados de demonstração de webapp/localService/mainService/data
npm run start-local # como o start, com SAPUI5 local
npm run start-noflp # index.html, sem launchpad
```

O `ui5.yaml` aponta para o SAP BTP, ABAP environment (`authenticationType: reentranceTicket`). Para um SAP
S/4HANA On-Premise, troque o `backend` como em [`ui5/README.md`](../../README.md#sistema-on-premise). Para ter
dados no sistema, carregue os dados de demonstração (`ZCL_PC_SETUP`).

> [!NOTE]
> O mock server soma o `ValorMedio` em vez de tirar a média como o backend: no `start-mock`, o ticket médio
> não é confiável. Use o mock só para a interface.

## Validar

```bash
npm run lint        # ESLint (@sap-ux/eslint-plugin-fiori-tools)
npm run build       # ui5 build → dist/
npm run unit-test   # suíte QUnit: catálogo, consultas $apply e moldagem das linhas
```

## Deploy

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # build + deploy da BSP ZPC_ANL_PEDIDOS
npm run undeploy      # remove a BSP
```

| | SAP BTP, ABAP environment | SAP S/4HANA On-Premise |
| --- | --- | --- |
| `ui5-deploy.yaml` | Como está: URL do sistema, `reentranceTicket`, `transport: ""` (pacotes do `ZLOCAL`) | URL e mandante do sistema, `credentials` por variáveis de ambiente e ordem de transporte Workbench |
| O que é criado | BSP `ZPC_ANL_PEDIDOS` e IAM App `ZPC_ANL_PEDIDOS_UI5R` | Só a BSP `ZPC_ANL_PEDIDOS` |
| Acesso | Tile pelo business catalog (ou tile URL no SAP Build Work Zone) | Catálogo `/UI2/FLPAM` e role `PFCG` |
| URL direta | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_anl_pedidos/index.html` | `https://<host>:<porta>/sap/bc/ui5_ui5/sap/zpc_anl_pedidos/index.html` |

O prefixo `ZAVBS` do pacote `ZAVBS_PC_PEDIDOS` é uma escolha pessoal do autor (iniciais do nome) e é opcional: no seu
projeto, troque o `package:` do `ui5-deploy.yaml` pelo pacote que você criou (sugestão genérica:
`ZPK_PC_PEDIDOS`; veja [`abap/README.md`](../../../abap/README.md#12-prefixo-dos-pacotes)).
Configuração On-Premise e conteúdo do launchpad: [`ui5/README.md`](../../README.md#sistema-on-premise).
Camada analítica no backend: [`abap/README.md`](../../../abap/README.md#10-camada-analítica).
