# Front-end Fiori – Pedidos de Compras

Três aplicações **SAP Fiori Elements (OData V4, List Report + Object Page)** geradas com o
**SAP Fiori tools** (Application Generator, template `@sap/generator-fiori:lrop`), uma para cada
serviço RAP do pacote `ZAVBS_PEDIDOS_COMPRAS`. Cada app é um **projeto isolado**: tem o próprio
`package.json`, `node_modules`, `ui5*.yaml` e é instalada, executada e publicada separadamente.

A UI é orientada a anotações. Colunas, filtros, seções, ações e criticidade vêm das Metadata
Extensions (`*.ddlx.cds`) do backend. Nas apps ficam só o `manifest.json` (rotas, páginas,
tabelas, tile) e a configuração das ferramentas.

| App                | Pasta              | `sap.app.id`     | Serviço (binding OData V4)  | Tile (inbound)           | BSP / pacote                         |
| ------------------ | ------------------ | ---------------- | --------------------------- | ------------------------ | ------------------------------------ |
| Gestão de Clientes | `gestao-clientes/` | `gestaoclientes` | `ZUI_PC_CLIENTES_O4`        | `ZPCCliente-manage`      | `ZPC_CLIENTES` / `ZAVBS_PC_CLIENTES` |
| Gestão de Estoque  | `gestao-estoque/`  | `gestaoestoque`  | `ZUI_PC_ESTOQUE_O4`         | `ZPCItemEstoque-manage`  | `ZPC_ESTOQUE` / `ZAVBS_PC_ESTOQUE`   |
| Pedidos de Compras | `pedidos-compras/` | `pedidoscompras` | `ZUI_PC_PEDIDOS_COMPRAS_O4` | `ZPCPedidoCompra-manage` | `ZPC_PEDIDOS` / `ZAVBS_PC_PEDIDOS`   |

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
| Pedidos  | `Pedido`, com as ações Confirmar / Simular pagamento / Aprovar / Cancelar / Aprovar e Rejeitar reembolso | Pedido. Itens criados na própria tabela (*inline*); Pagamento e Histórico do cliente como formulário (composição 0..1); tabela somente leitura de Reembolsos | `ItemPedido`, `ItemSnapshot`, `Reembolso` |

- As ações com parâmetros abrem o diálogo a partir das abstract entities `ZPC_A_PAGAMENTO_INPUT`,
  `ZPC_A_CANCELAMENTO_INPUT` e `ZPC_A_REEMB_DECISAO_INPUT`. Os botões de reembolso só ficam ativos
  com o pedido em `PROCESSAR_REEMBOLSO` (feature control do backend).
- O **CEP** do endereço é um campo padrão: o value help `ZC_PC_CEP_VH` sugere CEPs já cadastrados e
  a determination `PreencherEnderecoViaCep`, com side effects, preenche o restante do endereço.

### Navegação entre apps

As projeções do pedido marcam `ClienteUUID`/`NomeCliente` com o semantic object `ZPCCliente` e o
item com `ZPCItemEstoque`. A app de destino abre direto a Object Page quando recebe a chave
semântica: `Cpf` no Cliente (o `annotation.xml` de pedidos mapeia `CpfCliente` → `Cpf`) e `Sku` no
Item. A navegação funciona no launchpad do sistema, para quem tiver as duas apps nas suas roles.

## Executar localmente

```bash
cd ui5/<app>
npm install
npm start          # launchpad local (sandbox) com dados reais
npm run start-mock # dados de mock, sem backend
```

O proxy (`fiori-tools-proxy`) encaminha `/sap` para o sistema BTP ABAP com
`authenticationType: reentranceTicket`: na primeira chamada, o navegador abre o login do BTP.

## Validar

```bash
npm run lint       # ESLint (@sap-ux/eslint-plugin-fiori-tools)
npm run build      # ui5 build (dist/)
npm run int-test   # testes OPA5 gerados, com mock server
```

## Deploy no SAP BTP ABAP Environment

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # cria/atualiza a BSP ZPC_* e o IAM App ZPC_*_UI5R no pacote ZAVBS_PC_*
```

No trial, os pacotes do software component `ZLOCAL` não usam transporte. Em sistemas com
transporte, preencha `transport:` em `ui5-deploy.yaml`.

### Publicar os tiles no launchpad

1. **Business Catalogs (ADT):** adicionar o IAM App gerado (`ZPC_*_UI5R`) ao catálogo da app e
   **Publish Locally**.
2. **Business Roles:** atribuir os catálogos às roles no app *Maintain Business Roles*.
3. **Spaces e pages:** em *Manage Launchpad Spaces*, criar um espaço com uma página contendo os três
   tiles e atribuí-lo às roles.
