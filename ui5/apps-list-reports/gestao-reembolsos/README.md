# Gestão de Reembolsos

Decisão das solicitações de reembolso: aprovar (o pedido é cancelado e o pagamento devolvido) ou rejeitar
(o pedido volta ao status anterior). As solicitações nascem na app Pedidos de Compras, ao cancelar um pedido
já pago; aqui não há criação, edição nem exclusão.

| | |
| --- | --- |
| Tipo | SAP Fiori Elements V4: List Report + Object Page, sem draft |
| `sap.app.id` | `gestaoreembolsos` |
| Serviço | `ZUI_PC_REEMBOLSOS` (binding OData V4 `ZUI_PC_REEMBOLSOS_O4`) |
| Entity set | `Reembolso` |
| Tile (inbound) | `ZPCReembolso-manage` — "Gestão de Reembolsos" / "Aprovar ou rejeitar reembolsos" |
| BSP / pacote | `ZPC_REEMBOLSOS` / `ZAVBS_PC_REEMBOLSOS` |
| SAPUI5 mínimo | 1.136.7 |

## Telas

| Página | Rota | Conteúdo |
| --- | --- | --- |
| Lista de reembolsos | `#/` | Filtros pedido, cliente, CPF e status; colunas pedido, cliente, CPF, status, valor, motivo da solicitação, data da solicitação e motivo da decisão; botões **Aprovar** e **Rejeitar** |
| Reembolso | `#/Reembolso(...)` | Identificação, motivos e datas da solicitação e da decisão; botões **Aprovar reembolso** e **Rejeitar reembolso** |

| Lista | Pendente | Decisão | Aprovado |
| --- | --- | --- | --- |
| <img src="../../../assets/telas/reembolsos/lista.png" alt="Lista de reembolsos" width="215"> | <img src="../../../assets/telas/reembolsos/pendente.png" alt="Reembolso pendente" width="215"> | <img src="../../../assets/telas/reembolsos/aprovacao.png" alt="Diálogo Aprovar reembolso" width="215"> | <img src="../../../assets/telas/reembolsos/aprovado.png" alt="Reembolso aprovado" width="215"> |

## Comportamento

As colunas, filtros, seções e ações vêm da metadata extension `ZC_PC_REEMBOLSO_APP` do backend; a app não
tem extensões de código.

| Ação | Disponível com | Efeito no reembolso | Efeito no pedido |
| --- | --- | --- | --- |
| *Aprovar reembolso* | Status `PENDENTE` | `APROVADO` | `CANCELADO`, pagamento `DEVOLVIDO`, reserva liberada e snapshots gravados |
| *Rejeitar reembolso* (motivo obrigatório) | Status `PENDENTE` | `REJEITADO` | Volta ao status anterior ao cancelamento |

- Os botões ficam desabilitados fora do status `PENDENTE` (feature control do backend). O diálogo de decisão
  vem da abstract entity `ZPC_A_REEMB_DECISAO_INPUT`.
- A solicitação é criada pelo *Cancelar pedido* da app Pedidos de Compras quando o pagamento está aprovado;
  enquanto isso o pedido fica em `PROCESSANDO_REEMBOLSO`, com o estoque reservado.

<p align="center">
  <img src="../../../assets/telas/pedidos/cancelado.png" alt="Pedido cancelado pelo reembolso aprovado, com pagamento devolvido e o snapshot do cliente" width="700"><br>
  <sub>Pedido cancelado pelo reembolso aprovado, visto na app Pedidos de Compras</sub>
</p>

Regras completas do BO: [`abap/README.md`](../../../abap/README.md#93-reembolso-de-pedidos).

## Navegação

| Campo | Semantic object | Destino |
| --- | --- | --- |
| Pedido (`PedidoUUID` / `NumeroPedido`) | `ZPCPedidoCompra` | Pedidos de Compras, direto na página do pedido (link sem popover) |
| Cliente e CPF (`CpfCliente` → `Cpf`) | `ZPCCliente` | Gestão de Clientes |

- **Entrada**: *Abrir gestão* na Análise de Pedidos de Reembolsos (`ZPCReembolso-manage`).
- A navegação entre apps precisa de um launchpad (o do sistema ou o [launchpad local](../../launchpad/)).

## Estrutura

Este projeto é mais enxuto que as outras apps de gestão: não tem `ui5-local.yaml`, `ui5-mock.yaml`,
`localService/` nem testes OPA5.

```
gestao-reembolsos/
├── package.json            scripts (start, start-noflp, build, lint, deploy)
├── ui5.yaml                proxy /sap → sistema ABAP; SAPUI5 da CDN
├── ui5-deploy.yaml         deploy no ABAP Repository
└── webapp/
    ├── manifest.json       serviço, rotas Lista → Reembolso, inbound do tile
    ├── Component.js        sap/fe/core/AppComponent
    ├── index.html          página standalone (abre sem launchpad)
    ├── clearLaunchpadIntent.js   descarta o intent que tiles do tipo URL acrescentam ao hash
    ├── annotations/annotation.xml   anotações locais (vazio)
    └── i18n/i18n.properties textos pt-BR
```

## Executar

```bash
npm install
npm start           # launchpad de preview com dados reais (proxy /sap → sistema ABAP)
npm run start-noflp # index.html, sem launchpad
```

O `ui5.yaml` aponta para o SAP BTP, ABAP environment (`authenticationType: reentranceTicket`: o navegador
abre o login do BTP na primeira chamada). Para um SAP S/4HANA On-Premise, troque o `backend` como em
[`ui5/README.md`](../../README.md#sistema-on-premise).

Sem backend, abra a app pelo `npm run start-mock` do [launchpad local](../../launchpad/), que tem o metadata
deste serviço. Para ter solicitações reais, cancele um pedido pago na app Pedidos de Compras.

## Validar

```bash
npm run lint        # ESLint (@sap-ux/eslint-plugin-fiori-tools)
npm run build       # ui5 build → dist/
```

## Deploy

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # build + deploy da BSP ZPC_REEMBOLSOS
npm run undeploy      # remove a BSP
```

| | SAP BTP, ABAP environment | SAP S/4HANA On-Premise |
| --- | --- | --- |
| `ui5-deploy.yaml` | Como está: URL do sistema, `reentranceTicket`, `transport: ""` (pacotes do `ZLOCAL`) | URL e mandante do sistema, `credentials` por variáveis de ambiente e ordem de transporte Workbench |
| O que é criado | BSP `ZPC_REEMBOLSOS` e IAM App `ZPC_REEMBOLSOS_UI5R` | Só a BSP `ZPC_REEMBOLSOS` |
| Acesso | Tile pelo business catalog (ou tile URL no SAP Build Work Zone) | Catálogo `/UI2/FLPAM` e role `PFCG` |
| URL direta | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_reembolsos/index.html` | `https://<host>:<porta>/sap/bc/ui5_ui5/sap/zpc_reembolsos/index.html` |

O prefixo `ZAVBS` do pacote `ZAVBS_PC_REEMBOLSOS` é uma escolha pessoal do autor (iniciais do nome) e é opcional: no seu
projeto, troque o `package:` do `ui5-deploy.yaml` pelo pacote que você criou (sugestão genérica:
`ZPK_PC_REEMBOLSOS`; veja [`abap/README.md`](../../../abap/README.md#12-prefixo-dos-pacotes)).
Configuração On-Premise e conteúdo do launchpad: [`ui5/README.md`](../../README.md#sistema-on-premise).
Autorização: objeto `ZPC_PEDIDO`, atividade 16 (aprovar e rejeitar), em
[`abap/README.md`](../../../abap/README.md#6-autorização-authority-check-nos-dois-cenários).
