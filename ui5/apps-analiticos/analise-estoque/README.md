# Análise de Itens do Estoque

Painel somente leitura com indicadores e gráficos dos itens do estoque: quantidades reservadas e disponíveis
por categoria, situação do estoque, valor em estoque e itens mais reservados.

| | |
| --- | --- |
| Tipo | SAPUI5 freestyle (OData V4, somente leitura, gráficos `sap.viz`) |
| `sap.app.id` | `analiseestoque` |
| Serviço | `ZUI_PC_ANALITICO` (binding OData V4 `ZUI_PC_ANALITICO_O4`) |
| Entity set | `ItemAnalise` (`ZI_PC_ITEM_CUBE` → `ZC_PC_ITEM_ANALISE`) |
| Tile (inbound) | `ZPCAnaliseItemEstoque-display` — "Análise de Itens do Estoque" / "Categorias, reservas e valor em estoque" |
| BSP / pacote | `ZPC_ANL_ESTOQUE` / `ZAVBS_PC_ESTOQUE` |
| SAPUI5 mínimo | 1.136.0 |

## Telas

| Página | Rota | Conteúdo |
| --- | --- | --- |
| Painel | `#/` | Barra de filtros, indicadores e os 5 gráficos; o título de cada card abre o detalhe |
| Detalhe | `#/analise/<cenário>` | Gráfico grande com troca do tipo (colunas, barras, linha, rosca) e tabela com valores, % do total e linha de total |

<p align="center">
  <img src="../../../assets/telas/analises/estoque.png" alt="Painel da Análise de Itens do Estoque" width="700">
</p>

## Filtros e indicadores

| Filtros | Indicadores (KPIs) |
| --- | --- |
| Categoria e situação do estoque (listas com os valores do próprio serviço), nome e SKU (contém) | Itens, em estoque, reservada, disponível e valor em estoque |

Os filtros valem para os indicadores e para todos os gráficos, e continuam aplicados ao abrir um detalhe e ao
voltar. O valor em estoque é o preço unitário vezes a quantidade em estoque.

## Cenários

| Id | Título | Dimensão | Medidas | Gráfico | Ordem |
| --- | --- | --- | --- | --- | --- |
| `EstDisponivelPorCategoria` | Estoque por categoria | `Categoria` | `QtdeReservada`, `QtdeDisponivel` | Colunas | Maior disponível |
| `EstItensPorSituacao` | Itens por situação do estoque | `StatusEstoque` | `QtdeItens` | Rosca | Maior valor |
| `EstValorPorCategoria` | Valor em estoque por categoria | `Categoria` | `ValorEstoque` | Colunas | Maior valor |
| `EstMaisReservados` | Itens mais reservados (top 10) | `Nome` | `QtdeReservada` | Colunas | Maior valor, 10 primeiros |
| `EstItensPorCategoria` | Itens por categoria | `Categoria` | `QtdeItens` | Rosca | Maior valor |

Cada gráfico é uma consulta agregada no servidor. Exemplo do primeiro cenário:

```
ItemAnalise?$apply=groupby((Categoria,CategoriaTexto),aggregate(QtdeReservada,QtdeDisponivel))
```

As medidas usam a agregação padrão do backend (`@Aggregation.default`), por isso o `aggregate` não informa o
método. Se um gráfico vier vazio ou com erro de `groupby`, teste a URL acima no navegador.

## Navegação

- **Abrir gestão** abre a app Gestão de Estoque: pelo intent `ZPCItemEstoque-manage` no launchpad; fora
  dele, pela BSP irmã (`../zpc_estoque/index.html`) em outra aba.
- Um hash desconhecido (por exemplo, um link antigo `#/painel/<domínio>` do app único de análises) volta ao
  painel.

## Estrutura

```
analise-estoque/
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
    ├── localService/mainService/   metadata.xml e data/ItemAnalise.json (dados de demonstração)
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

## Validar

```bash
npm run lint        # ESLint (@sap-ux/eslint-plugin-fiori-tools)
npm run build       # ui5 build → dist/
npm run unit-test   # suíte QUnit: catálogo, consultas $apply e moldagem das linhas
```

## Deploy

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # build + deploy da BSP ZPC_ANL_ESTOQUE
npm run undeploy      # remove a BSP
```

| | SAP BTP, ABAP environment | SAP S/4HANA On-Premise |
| --- | --- | --- |
| `ui5-deploy.yaml` | Como está: URL do sistema, `reentranceTicket`, `transport: ""` (pacotes do `ZLOCAL`) | URL e mandante do sistema, `credentials` por variáveis de ambiente e ordem de transporte Workbench |
| O que é criado | BSP `ZPC_ANL_ESTOQUE` e IAM App `ZPC_ANL_ESTOQUE_UI5R` | Só a BSP `ZPC_ANL_ESTOQUE` |
| Acesso | Tile pelo business catalog (ou tile URL no SAP Build Work Zone) | Catálogo `/UI2/FLPAM` e role `PFCG` |
| URL direta | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_anl_estoque/index.html` | `https://<host>:<porta>/sap/bc/ui5_ui5/sap/zpc_anl_estoque/index.html` |

O prefixo `ZAVBS` do pacote `ZAVBS_PC_ESTOQUE` é uma escolha pessoal do autor (iniciais do nome) e é opcional: no seu
projeto, troque o `package:` do `ui5-deploy.yaml` pelo pacote que você criou (sugestão genérica:
`ZPK_PC_ESTOQUE`; veja [`abap/README.md`](../../../abap/README.md#12-prefixo-dos-pacotes)).
Configuração On-Premise e conteúdo do launchpad: [`ui5/README.md`](../../README.md#sistema-on-premise).
Camada analítica no backend: [`abap/README.md`](../../../abap/README.md#10-camada-analítica).
