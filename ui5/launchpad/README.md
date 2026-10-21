# Launchpad local

Projeto UI5 só para desenvolvimento que simula o SAP Fiori launchpad (sandbox do `sap.ushell`) e reúne as
oito apps do projeto. Não tem build nem deploy: no sistema, o papel dele é do launchpad do SAP BTP ou do
SAP S/4HANA.

<p align="center">
  <img src="../../assets/telas/launchpad/inicio.png" alt="Launchpad local com os oito tiles: quatro de gestão e quatro de análise" width="800">
</p>

| Grupo | Tiles (intent) |
| --- | --- |
| Gestão | Gestão de Clientes (`ZPCCliente-manage`), Gestão de Estoque (`ZPCItemEstoque-manage`), Pedidos de Compras (`ZPCPedidoCompra-manage`), Gestão de Reembolsos (`ZPCReembolso-manage`) |
| Análises | Análise de Pedidos de Compras (`ZPCAnalisePedido-display`), Análise de Clientes (`ZPCAnaliseCliente-display`), Análise de Itens do Estoque (`ZPCAnaliseItemEstoque-display`), Análise de Pedidos de Reembolsos (`ZPCAnaliseReembolso-display`) |

Cada tile abre a app vizinha pelo mesmo intent do inbound do `manifest.json` dela. Por isso a navegação entre
apps funciona aqui como no launchpad do sistema: pedido → cliente / item, reembolso → pedido e *Abrir gestão*
nas análises.

## Executar

```bash
npm install
npm start           # dados reais: proxy /sap → sistema ABAP (login no navegador na primeira chamada)
npm run start-mock  # sem backend: mock server com o metadata de webapp/localService/
npm run lint        # ESLint
```

- As apps são servidas direto do `webapp/` de cada projeto (`fiori-tools-servestatic`, em
  `/apps/<sap.app.id>`): alterações nelas aparecem aqui sem build. Não é preciso rodar `npm install` nas apps
  para usá-las pelo launchpad, só para os comandos delas.
- O `ui5.yaml` aponta para o SAP BTP, ABAP environment (`authenticationType: reentranceTicket`). Para um SAP
  S/4HANA On-Premise, troque o `backend` como em [`ui5/README.md`](../README.md#sistema-on-premise).
- No `start-mock`, os dados de Clientes, Estoque, Pedidos e Reembolsos são gerados pelo mock server (valores
  como `Nome_1`) e as ações não executam; as Análises usam os dados de demonstração de
  `webapp/localService/analitico/data/` (os mesmos `data/*.json` dos apps de análise).

## Estrutura

```
launchpad/
├── package.json            scripts (start, start-mock, lint)
├── ui5.yaml                proxy /sap → sistema ABAP + publicação das apps vizinhas em /apps/<sap.app.id>
├── ui5-mock.yaml           igual, com o mock server dos cinco serviços no lugar do backend
└── webapp/
    ├── index.html          bootstrap do sandbox (sap.ushell) e do SAPUI5
    ├── manifest.json
    ├── appconfig/fioriSandboxConfig.json   grupos, tiles e targets (intent → /apps/<id>)
    ├── launchpad/init.js   cria o shell (renderer fiori2)
    └── localService/       metadata de clientes, estoque, pedidos, reembolsos e analitico (com os dados de demonstração)
```

Os tiles e targets ficam em `appconfig/fioriSandboxConfig.json` e não em `window["sap-ushell-config"]`: o
sandbox carrega a própria configuração padrão (com o grupo *Sample Applications*) por cima do objeto da
página, e só o `appconfig` é aplicado depois dela.

## Manutenção

- **Incluir uma app**: um tile em `groups`, um target em `NavTargetResolution.applications` (chave = intent
  do inbound, `url` = `/apps/<sap.app.id>`) e o caminho em `fiori-tools-servestatic` no `ui5.yaml` e no
  `ui5-mock.yaml`.
- **Atualizar o metadata** depois de mudar um serviço: baixe `…/0001/$metadata` pelo `npm start` e substitua
  o arquivo em `webapp/localService/<serviço>/`.
