# Análises de Compras (React)

Versão em **React** do app de análises, feita com a biblioteca
[UI5 Web Components for React](https://ui5.github.io/webcomponents-react/v2/?path=/docs/getting-started--docs)
(`@ui5/webcomponents-react` 2.27, tema SAP Horizon, gráficos em `@ui5/webcomponents-react-charts`).
Tem as mesmas telas, filtros e os mesmos 20 cenários de [`../analise-compras`](../analise-compras/) (SAPUI5),
sobre o mesmo serviço `ZUI_PC_ANALITICO_O4`, somente leitura.

- **Painel** (`#/painel/<domínio>`): filtros, indicadores e os 5 gráficos do domínio.
- **Detalhe** (`#/analise/<cenário>`, pelo título do card): gráfico com troca de tipo (colunas, barras, linha,
  rosca) e tabela com valores, % do total e linha de total. Os filtros continuam aplicados.
- Em telas estreitas (< 1024 px) o seletor de domínio vira lista suspensa.

## Executar

```bash
npm install
npm run dev:mock    # dados de demonstração (mock/data), sem backend: http://localhost:5173
npm run dev         # proxy de /sap para o ABAP (veja "Backend real")
npm test            # Vitest: catálogo, consultas $apply, serviço e mock
npm run typecheck
npm run build       # dist/ (HashRouter e base relativa: roda em qualquer caminho de BSP)
```

### Backend real

O login do ABAP trial é por SAP ID, então o proxy do Vite não consegue autenticar sozinho. Em
`.env.local` (não versionado) informe `BACKEND_URL` (padrão: o host do trial do projeto) e
`BACKEND_COOKIE` (o cabeçalho `Cookie` copiado de uma sessão do navegador já logada no ABAP). Em
produção (BSP) o app roda na mesma origem do serviço e usa a sessão do navegador, sem token nem CORS.

## Estrutura

```
src/
├── model/scenarios.ts        catálogo: domínios, filtros, KPIs e os 20 cenários
├── model/analyticsQuery.ts   monta o $apply e molda as linhas (sem React nem rede)
├── model/formatters.ts       moeda, números e % (Intl, pt-BR)
├── service/analyticsService.ts  GET ...?$apply=filter()/groupby()/aggregate()
├── state/FiltersContext.tsx  valores dos filtros por domínio (sobrevivem à navegação)
├── components/               AnalysisChart, FilterPanel, KpiTiles, ScenarioCard
├── pages/                    DashboardPage e DetailPage (DynamicPage)
└── i18n/texts.ts             textos pt-BR (mesmas chaves do i18n do app SAPUI5)
mock/                         plugin do Vite com um interpretador de $apply + dados de demonstração
```

Para **incluir um cenário**, acrescente uma entrada em `src/model/scenarios.ts` e os textos
`<id>.title` / `<id>.sub` em `src/i18n/texts.ts` (o teste do catálogo falha se faltar alguma chave).

## Deploy no ABAP

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # BSP ZPC_ANALISE_R e IAM App ZPC_ANALISE_R_UI5R no pacote ZAVBS_PC_COMMON
```

Usa o `@sap-ux/deploy-tooling` (versão exata no script, chamado via `npx`) com `ui5-deploy.yaml` e a pasta
`dist`. Depois: `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_analise_r/index.html`.

> [!NOTE]
> O deploy ainda não foi executado no sistema. O build tem ~300 arquivos porque as bibliotecas UI5 geram um
> arquivo por idioma e por tema (carregados só sob demanda: o navegador baixa apenas os do idioma em uso).
