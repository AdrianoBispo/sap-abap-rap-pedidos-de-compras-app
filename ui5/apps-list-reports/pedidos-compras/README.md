# Pedidos de Compras

Ciclo completo do pedido de compra: criação com reserva de estoque, pagamento simulado com cartão, aprovação
com baixa do estoque e cancelamento, com abertura de reembolso quando o pedido já foi pago.

| | |
| --- | --- |
| Tipo | SAP Fiori Elements V4: List Report + Object Page, com draft |
| `sap.app.id` | `pedidoscompras` |
| Serviço | `ZUI_PC_PEDIDOS_COMPRAS` (binding OData V4 `ZUI_PC_PEDIDOS_COMPRAS_O4`) |
| Entity sets | `Pedido` (raiz), `ItemPedido`, `Pagamento`, `ClienteSnapshot`, `ItemSnapshot` |
| Tile (inbound) | `ZPCPedidoCompra-manage` — "Pedidos de Compras" / "Criar, pagar, aprovar e reembolsar" |
| BSP / pacote | `ZPC_PEDIDOS` / `ZAVBS_PC_PEDIDOS` |
| SAPUI5 mínimo | 1.136.7 |

## Telas

| Página | Rota | Conteúdo |
| --- | --- | --- |
| Lista de pedidos | `#/` | Filtros cliente, CPF, status do pedido e do pagamento, valor total e data; colunas número, cliente, CPF, status, valor total, data do pedido e de finalização; menu **Ações** e botão **Importar planilha** |
| Pedido | `#/Pedido(...)` | Seções *Dados do Cliente*, *Dados do Pedido*, *Itens*, *Pagamento (última tentativa)* e, conforme o status, *Finalização* ou *Cancelamento* |
| Item do pedido | `#/Pedido(...)/_Itens(...)` | Item, SKU, quantidade disponível agora, quantidade, preço unitário, total e observação |
| Item do histórico | `#/Pedido(...)/_ItensSnapshot(...)` | Item como estava na finalização ou no cancelamento |

| Lista | Rascunho com itens *inline* | Efetuar pagamento |
| --- | --- | --- |
| <img src="../../../assets/telas/pedidos/lista.png" alt="Lista de pedidos" width="290"> | <img src="../../../assets/telas/pedidos/rascunho.png" alt="Pedido em rascunho com dois itens" width="290"> | <img src="../../../assets/telas/pedidos/pagamento.png" alt="Diálogo da action Efetuar Pagamento" width="290"> |

| Pedido finalizado (snapshot) | Cancelamento de pedido pago |
| --- | --- |
| <img src="../../../assets/telas/pedidos/finalizado.png" alt="Pedido finalizado com o snapshot do cliente" width="440"> | <img src="../../../assets/telas/pedidos/cancelamento.png" alt="Diálogo Cancelar pedido com motivo" width="440"> |

## Comportamento

As colunas, filtros, seções, ações e a criticidade vêm das metadata extensions do backend
(`ZC_PC_PEDIDO_APP` e filhas). Na app ficam só o `manifest.json` (rotas e criação *inline* dos itens) e o
mapeamento local do CPF para a navegação.

| Status do pedido | Como chega | O que a app permite |
| --- | --- | --- |
| `ABERTO` | *Salvar* do rascunho (reserva o estoque) ou pagamento recusado | *Editar* (só os itens), *Efetuar Pagamento*, *Cancelar pedido* |
| `AGUARDANDO_APROVACAO` | Pagamento aprovado | *Aprovar pedido*, *Cancelar pedido* |
| `FINALIZADO` | *Aprovar pedido*: baixa o estoque e grava os snapshots | Somente leitura |
| `PROCESSANDO_REEMBOLSO` | *Cancelar pedido* com pagamento aprovado: abre a solicitação de reembolso | Aguarda a decisão na app Gestão de Reembolsos |
| `CANCELADO` | *Cancelar pedido* sem pagamento aprovado (libera a reserva) ou reembolso aprovado | Somente leitura |

- **Criação**: escolha o cliente; os itens são incluídos na própria tabela (*inline*), só no rascunho. Item
  sem quantidade disponível é recusado ao ser incluído. Não há botão de confirmação: o *Salvar* valida
  endereço principal, itens e disponibilidade e reserva o estoque.
- **Edição** de pedido `ABERTO`: o cliente fica somente leitura e a reserva é ajustada pela diferença dos
  itens. O pedido não tem *Excluir*.
- **Ações** agrupadas no menu "Ações", na lista e no pedido; o backend habilita cada uma conforme o status.
  *Efetuar Pagamento* abre um diálogo com método, cartão, validade e CVV; só bandeira, últimos 4 dígitos e
  máscara são gravados. *Cancelar pedido* exige o motivo.
- **Seções dinâmicas**: em pedidos `FINALIZADO` ou `CANCELADO`, cliente e itens vêm dos snapshots (histórico
  imutável); nos demais, das tabelas principais.
- **Importar planilha** (CSV ou XLSX, até 500 linhas, tudo ou nada): uma linha por item; a coluna *Pedido*
  agrupa as linhas e evita importar o mesmo pedido duas vezes. Os pedidos nascem `ABERTO` com o estoque
  reservado. Colunas e regras em
  [`abap/README.md`](../../../abap/README.md#94-importação-em-massa-por-planilha); modelo em
  [`docs/modelos-importacao/`](../../../docs/modelos-importacao).

Dados de teste do pagamento: cartão `4111 1111 1111 1111`, validade `12/30` e CVV `123` aprovam; CVV `000`
recusa. Regras completas: [`abap/README.md`](../../../abap/README.md#91-clientes-estoque-e-pedidos) e
[reembolso](../../../abap/README.md#93-reembolso-de-pedidos).

## Navegação

| Campo | Semantic object | Destino |
| --- | --- | --- |
| Cliente e CPF do pedido e do snapshot do cliente | `ZPCCliente` | Gestão de Clientes |
| Item e SKU dos itens e do snapshot dos itens | `ZPCItemEstoque` | Gestão de Estoque |

- **Entrada**: o link *Pedido* da app Gestão de Reembolsos e *Abrir gestão* na Análise de Pedidos de
  Compras abrem esta app (`ZPCPedidoCompra-manage`); com `PedidoUUID` ou `NumeroPedido` no intent, a app abre
  direto o pedido.
- No pedido, o CPF chama `CpfCliente`; `webapp/annotations/annotation.xml` repete o mapeamento
  `CpfCliente` → `Cpf` do backend para os links de cliente.
- A navegação entre apps precisa de um launchpad (o do sistema ou o [launchpad local](../../launchpad/)).

## Estrutura

```
pedidos-compras/
├── package.json            scripts (start, start-mock, build, lint, int-test, deploy)
├── ui5.yaml                proxy /sap → sistema ABAP; SAPUI5 da CDN
├── ui5-local.yaml          igual, com SAPUI5 local
├── ui5-mock.yaml           mock server com webapp/localService/
├── ui5-deploy.yaml         deploy no ABAP Repository
└── webapp/
    ├── manifest.json       serviço, rotas Lista → Pedido → Item / Item do histórico, itens inline, inbound do tile
    ├── Component.js        sap/fe/core/AppComponent
    ├── index.html          página standalone (abre sem launchpad)
    ├── clearLaunchpadIntent.js   descarta o intent que tiles do tipo URL acrescentam ao hash
    ├── annotations/annotation.xml   mapeamento CpfCliente → Cpf (semantic object ZPCCliente)
    ├── i18n/i18n.properties textos pt-BR
    ├── localService/mainService/    metadata do serviço e dos value helps, para o mock
    └── test/integration/   testes OPA5 gerados (lista e Object Page)
```

## Executar

```bash
npm install
npm start           # launchpad de preview com dados reais (proxy /sap → sistema ABAP)
npm run start-mock  # sem backend: mock server com dados gerados a partir do metadata
npm run start-local # como o start, com SAPUI5 local
npm run start-noflp # index.html, sem launchpad
```

O `ui5.yaml` aponta para o SAP BTP, ABAP environment (`authenticationType: reentranceTicket`: o navegador
abre o login do BTP na primeira chamada). Para um SAP S/4HANA On-Premise, troque o `backend` como em
[`ui5/README.md`](../../README.md#sistema-on-premise). O mock server não executa as ações nem as regras do
backend: use-o só para a interface.

## Validar

```bash
npm run lint        # ESLint (@sap-ux/eslint-plugin-fiori-tools)
npm run build       # ui5 build → dist/
npm run int-test    # OPA5 com o mock server
```

## Deploy

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # build + deploy da BSP ZPC_PEDIDOS
npm run undeploy      # remove a BSP
```

| | SAP BTP, ABAP environment | SAP S/4HANA On-Premise |
| --- | --- | --- |
| `ui5-deploy.yaml` | Como está: URL do sistema, `reentranceTicket`, `transport: ""` (pacotes do `ZLOCAL`) | URL e mandante do sistema, `credentials` por variáveis de ambiente e ordem de transporte Workbench |
| O que é criado | BSP `ZPC_PEDIDOS` e IAM App `ZPC_PEDIDOS_UI5R` | Só a BSP `ZPC_PEDIDOS` |
| Acesso | Tile pelo business catalog (ou tile URL no SAP Build Work Zone) | Catálogo `/UI2/FLPAM` e role `PFCG` |
| URL direta | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_pedidos/index.html` | `https://<host>:<porta>/sap/bc/ui5_ui5/sap/zpc_pedidos/index.html` |

O prefixo `ZAVBS` do pacote `ZAVBS_PC_PEDIDOS` é uma escolha pessoal do autor (iniciais do nome) e é opcional: no seu
projeto, troque o `package:` do `ui5-deploy.yaml` pelo pacote que você criou (sugestão genérica:
`ZPK_PC_PEDIDOS`; veja [`abap/README.md`](../../../abap/README.md#12-prefixo-dos-pacotes)).
Configuração On-Premise e conteúdo do launchpad: [`ui5/README.md`](../../README.md#sistema-on-premise).
Autorização: objeto `ZPC_PEDIDO` (01 criar e importar, 02 alterar, 16 pagar, aprovar e cancelar), em
[`abap/README.md`](../../../abap/README.md#6-autorização-authority-check-nos-dois-cenários).

---

Gerada com o SAP Fiori Application Generator 1.28.0 (template *List Report Page V4*, OData URL) em
27/09/2026; os dados da geração estão em `.appGenInfo.json`.
