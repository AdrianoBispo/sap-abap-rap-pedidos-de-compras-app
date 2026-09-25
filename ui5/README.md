# Front-end Fiori – Pedidos de Compras

Três aplicações **SAP Fiori Elements (OData V4, List Report + Object Page)**, uma para cada
serviço RAP do projeto. A UI é **orientada a anotações**: colunas, filtros, seções, ações e
criticidade vêm das Metadata Extensions (`*.ddlx.cds`) do backend. Aqui ficam apenas o
`manifest.json` (serviço, rotas, tabelas, tile do launchpad) e a configuração de ferramentas.

| App                | Pasta       | ID / namespace | Serviço (binding OData V4)  | Semantic object (tile)   | BSP no deploy  |
| ------------------ | ----------- | -------------- | --------------------------- | ------------------------ | -------------- |
| Gestão de Clientes | `clientes/` | `zpc.clientes` | `ZUI_PC_CLIENTES_O4`        | `ZPCCliente-manage`      | `ZPC_CLIENTES` |
| Gestão de Estoque  | `estoque/`  | `zpc.estoque`  | `ZUI_PC_ESTOQUE_O4`         | `ZPCItemEstoque-manage`  | `ZPC_ESTOQUE`  |
| Pedidos de Compras | `pedidos/`  | `zpc.pedidos`  | `ZUI_PC_PEDIDOS_COMPRAS_O4` | `ZPCPedidoCompra-manage` | `ZPC_PEDIDOS`  |

## Estrutura

```
ui5/
├── clientes/
│   ├── package.json          scripts start / build / lint / deploy
│   ├── ui5.yaml              servidor local: proxy /sap → BTP, UI5 da CDN, launchpad local
│   ├── ui5-deploy.yaml       deploy no ABAP Repository (BSP + IAM App)
│   └── webapp/
│       ├── manifest.json     serviço OData V4, rotas LR → OP → sub-OP, tile (inbound)
│       ├── Component.js      sap/fe/core/AppComponent
│       ├── index.html        execução sem launchpad
│       ├── i18n/             i18n.properties (pt-BR, padrão) e i18n_en.properties
│       ├── ext/              (só clientes) campo customizado "CEP": fragment/ + util/CepUtil.js
│       └── test/             (só clientes) testes QUnit da extensão (UI5 Test Starter)
├── estoque/                  mesma estrutura
└── pedidos/                  mesma estrutura, mais:
    ├── ui5-launchpad.yaml    launchpad local com as TRÊS apps (tiles + navegação entre apps)
    └── webapp/annotations/annotation.xml   mapeamento CpfCliente → Cpf da navegação
```

### Páginas de cada app

| App      | List Report                                                               | Object Page                                                                                                                            | Sub-páginas                                                    |
| -------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Clientes | `Cliente`                                                                 | Cliente, com tabela de endereços e ação **Definir endereço principal**                                                                 | `Endereco` (criação em página própria; o **CEP** do formulário é um campo customizado que consulta o ViaCEP) |
| Estoque  | `Item`                                                                    | Item (foto, estoque, dimensões)                                                                                                        | —                                                              |
| Pedidos  | `Pedido`, com as ações Confirmar / Simular pagamento / Aprovar / Cancelar | Pedido. Os itens são criados na própria tabela (*inline*); Pagamento e Histórico do cliente aparecem como formulário (composição 0..1) | `ItemPedido`, `ItemSnapshot`                                   |

As ações com parâmetros (**Simular pagamento**, **Cancelar pedido**) abrem o diálogo automaticamente a
partir das abstract entities `ZPC_A_PAGAMENTO_INPUT` e `ZPC_A_CANCELAMENTO_INPUT`.

### Navegação entre apps

As projeções do pedido marcam `ClienteUUID`/`NomeCliente` com o semantic object `ZPCCliente` e
`ItemUUID`/`Sku` com `ZPCItemEstoque` (`@Consumption.semanticObject`). No pedido, o cliente e o
item viram links. O popover leva para a app de Clientes ou de Estoque, que abre direto a Object Page
quando recebe a chave semântica: `Cpf` no cliente (o `annotation.xml` renomeia `CpfCliente`) e `Sku`
no item.

## Pré-requisitos

- Node.js 20 ou superior.
- SAP Business Application Studio **ou** VS Code com a extensão *SAP Fiori Tools*.
- Backend ativado e **Service Bindings publicados**.
- Usuário com as Business Roles do projeto no sistema BTP ABAP.
- O SAP Fiori launchpad do sistema com **SAPUI5 1.136 ou superior**. O `manifest.json` usa
  descriptor versão 2 (`_version` 2.0.0).

## Validar

```bash
npm run build   # ui5 build das três apps (dist/)
npm run lint    # UI5 linter (compatibilidade com UI5 2.x, APIs depreciadas, manifest)
```

## Deploy no SAP BTP ABAP Environment

```bash
npm run deploy                   # as três apps
npm run deploy:pedidos           # ou uma a uma
```

Cada deploy cria ou atualiza:

- a aplicação **BSP** (`ZPC_CLIENTES`, `ZPC_ESTOQUE`, `ZPC_PEDIDOS`) no pacote do BO correspondente;
- o **IAM App** `<BSP>_UI5R`, que representa o tile.

No trial, os pacotes do software component `ZLOCAL` não usam transporte; em sistemas com transporte,
preencha `transport:` em `ui5-deploy.yaml`. Para testar sem gravar nada: `npm run deploy-test -w <app>`.

### Publicar os tiles no launchpad

1. **Business Catalogs (ADT).** Adicionar o IAM App gerado ao catálogo correspondente (*Apps* →
   *Add*) e **Publish Locally**:

   | Business Catalog  | IAM Apps                                                      |
   | ----------------- | ------------------------------------------------------------- |
   | `ZPC_BC_CLIENTES` | `ZPC_IAM_CLIENTES_EXT` (serviço) + `ZPC_CLIENTES_UI5R` (tile) |
   | `ZPC_BC_ESTOQUE`  | `ZPC_IAM_ESTOQUE_EXT` + `ZPC_ESTOQUE_UI5R`                    |
   | `ZPC_BC_PEDIDOS`  | `ZPC_IAM_PEDIDOS_EXT` + `ZPC_PEDIDOS_UI5R`                    |

2. **Business Roles.** Nas roles `ZPC_BR_ADMIN` (três catálogos) e `ZPC_BR_COMUM` (Pedidos), use o app
   *Maintain Business Roles*. Os catálogos já atribuídos passam a trazer os tiles.
3. **Spaces e pages.** No app *Manage Launchpad Spaces*, crie um espaço, por exemplo `ZPC_SPACE`, com
   uma página contendo os três tiles e atribua-o às Business Roles.
4. **Navegação entre apps.** Funciona para o usuário que tiver as duas apps nas suas roles (ex.:
   `ZPC_BR_ADMIN`). Para `ZPC_BR_COMUM`, os links de cliente e item aparecem sem destino.

## Personalização

- **Textos e colunas.** Alterar as Metadata Extensions no backend (não é preciso redeploy do front-end).
- **Tabelas.** Tipo, modo de seleção e modo de criação ficam em `manifest.json` →
  `routing.targets.<Página>.options.settings.controlConfiguration`.
- **Extensões.** Para seções, colunas ou ações próprias em JavaScript, use o *Page Map* do SAP Fiori
  tools, que grava em `manifest.json` → `controlConfiguration`/`content` e cria a pasta `ext/`.
