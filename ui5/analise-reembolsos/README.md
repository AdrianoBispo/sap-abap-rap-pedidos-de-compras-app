# Análise de Pedidos de Reembolsos

App SAPUI5 **freestyle** (OData V4, somente leitura) com as análises das solicitações de
reembolso: 5 cenários de gráfico sobre o entity set `ReembolsoAnalise` do serviço
`ZUI_PC_ANALITICO` (`/sap/opu/odata4/sap/zui_pc_analitico_o4/srvd/sap/zui_pc_analitico/0001/`).

- **Painel** (`#/`): filtros (status do reembolso, UF e mês da solicitação), indicadores
  (reembolsos e valor dos reembolsos) e os 5 gráficos.
- **Detalhe** (`#/analise/<cenário>`): gráfico com troca de tipo, tabela de valores e % do total.
- **Abrir gestão**: abre o app Gestão de Reembolsos (`ZPCReembolso-manage`).
- Cenários, estrutura e como incluir um novo: veja [`../README.md`](../README.md#apps-de-análise-freestyle).

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
npm run deploy        # BSP ZPC_ANL_REEMB e IAM App ZPC_ANL_REEMB_UI5R no pacote ZAVBS_PC_REEMBOLSOS
```

Depois do deploy: `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_anl_reemb/index.html`.
Intent do tile: `ZPCAnaliseReembolso-display`.
