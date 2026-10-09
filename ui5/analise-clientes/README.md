# Análise de Clientes

App SAPUI5 **freestyle** (OData V4, somente leitura) com as análises dos clientes: 5 cenários de
gráfico sobre o entity set `ClienteAnalise` do serviço `ZUI_PC_ANALITICO`
(`/sap/opu/odata4/sap/zui_pc_analitico_o4/srvd/sap/zui_pc_analitico/0001/`).

- **Painel** (`#/`): filtros (gênero, cliente ativo, UF, faixa do score e nome), indicadores
  (clientes e score médio) e os 5 gráficos.
- **Detalhe** (`#/analise/<cenário>`): gráfico com troca de tipo, tabela de valores e % do total.
- **Abrir gestão**: abre o app Gestão de Clientes (`ZPCCliente-manage`).
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
npm run deploy        # BSP ZPC_ANL_CLIENTE e IAM App ZPC_ANL_CLIENTE_UI5R no pacote ZAVBS_PC_CLIENTES
```

Depois do deploy: `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_anl_cliente/index.html`.
Intent do tile: `ZPCAnaliseCliente-display`.
