# Análises de Compras

App SAPUI5 **freestyle** (OData V4, somente leitura) com todas as análises de Pedidos, Clientes,
Estoque e Reembolsos: 20 cenários de gráfico sobre o serviço `ZUI_PC_ANALITICO`
(`/sap/opu/odata4/sap/zui_pc_analitico_o4/srvd/sap/zui_pc_analitico/0001/`).

- **Painel** (`#/painel/<domínio>`): filtros, indicadores e os 5 gráficos do domínio.
- **Detalhe** (`#/analise/<cenário>`): gráfico com troca de tipo, tabela de valores e % do total.
- Cenários, estrutura e como incluir um novo: veja [`../README.md`](../README.md#app-de-análises-freestyle).

## Executar

```bash
npm install
npm start           # launchpad local (sandbox) com dados reais do sistema BTP
npm run start-mock  # dados de demonstração de webapp/localService/mainService/data
npm run unit-test   # suíte QUnit (catálogo, consultas, moldagem das linhas)
npm run lint
npm run build
```

## Deploy

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # BSP ZPC_ANALISE e IAM App ZPC_ANALISE_UI5R no pacote ZAVBS_PC_COMMON
```

Depois do deploy: `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_analise/index.html`.
Intent do tile: `ZPCAnalise-display`.
