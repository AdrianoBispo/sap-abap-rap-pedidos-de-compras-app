# Gestão de Estoque

Cadastro dos itens vendidos nos pedidos: nome, categoria, preço, foto e quantidade em estoque. A app mostra
quanto está reservado pelos pedidos em aberto e quanto ainda está disponível.

| | |
| --- | --- |
| Tipo | SAP Fiori Elements V4: List Report + Object Page, com draft |
| `sap.app.id` | `gestaoestoque` |
| Serviço | `ZUI_PC_ESTOQUE` (binding OData V4 `ZUI_PC_ESTOQUE_O4`) |
| Entity set | `Item` |
| Tile (inbound) | `ZPCItemEstoque-manage` — "Gestão de Estoque" / "Itens, SKU e disponibilidade" |
| BSP / pacote | `ZPC_ESTOQUE` / `ZAVBS_PC_ESTOQUE` |
| SAPUI5 mínimo | 1.136.7 |

## Telas

| Página | Rota | Conteúdo |
| --- | --- | --- |
| Lista de itens | `#/` | Filtros SKU, nome, categoria, ativo, quantidade disponível e status; colunas SKU, nome, categoria, preço unitário, ativo, quantidades em estoque, reservada e disponível e status; botão **Importar planilha** |
| Item | `#/Item(...)` | Status do estoque no cabeçalho; seções *Dados do item*, *Estoque* e *Dados administrativos* |

| Lista | Item |
| --- | --- |
| <img src="../../assets/telas/estoque/lista.png" alt="Lista de itens de estoque" width="440"> | <img src="../../assets/telas/estoque/item.png" alt="Object Page do item com SKU gerado no Save" width="440"> |

## Comportamento

As colunas, filtros, seções e ações vêm da metadata extension `ZC_PC_ITEM_APP` do backend; a app não tem
extensões de código.

- **Criar e editar** em rascunho (draft).
- **SKU** gerado no *Salvar* com as 3 primeiras letras da categoria e um sequencial (`SKU-ELE-0000000001`);
  não é digitado.
- **Quantidades**: a quantidade em estoque é editável; a reservada e a disponível são somente leitura e mudam
  só pelos pedidos (registro, aprovação e cancelamento na app Pedidos de Compras). O serviço não expõe as
  ações de reserva e baixa.
- **Status do estoque** recalculado a cada movimentação: *Sem estoque*, *Acabando* (até 10 disponíveis) ou
  *Em estoque*.
- **Foto** (JPEG, PNG ou WEBP) na página do item.
- **Concorrência**: enquanto um item está em edição aqui, o *Salvar* de um pedido com esse item é recusado
  (`ITEM_ESTOQUE_CONCORRENTE`). Salve ou descarte o rascunho para liberar o item.
- **Importar planilha** (CSV ou XLSX, até 500 linhas, tudo ou nada): uma linha por item, moeda padrão `BRL`.
  Colunas e regras em [`abap/README.md`](../../abap/README.md#94-importação-em-massa-por-planilha); modelo
  em [`docs/modelos-importacao/`](../../docs/modelos-importacao).

Regras completas do BO: [`abap/README.md`](../../abap/README.md#91-clientes-estoque-e-pedidos).

## Navegação

- **Entrada**: item e SKU nos itens de um pedido (app Pedidos de Compras) e *Abrir gestão* na Análise de
  Itens do Estoque abrem esta app pelo semantic object `ZPCItemEstoque`. Com `ItemUUID` ou `Sku` no intent,
  a app abre direto a página do item.
- A navegação entre apps precisa de um launchpad (o do sistema ou o [launchpad local](../launchpad/)).

## Estrutura

```
gestao-estoque/
├── package.json            scripts (start, start-mock, build, lint, int-test, deploy)
├── ui5.yaml                proxy /sap → sistema ABAP; SAPUI5 da CDN
├── ui5-local.yaml          igual, com SAPUI5 local
├── ui5-mock.yaml           mock server com webapp/localService/
├── ui5-deploy.yaml         deploy no ABAP Repository
└── webapp/
    ├── manifest.json       serviço, rotas Lista → Item, inbound do tile
    ├── Component.js        sap/fe/core/AppComponent
    ├── index.html          página standalone (abre sem launchpad)
    ├── clearLaunchpadIntent.js   descarta o intent que tiles do tipo URL acrescentam ao hash
    ├── annotations/annotation.xml   anotações locais (vazio)
    ├── i18n/i18n.properties textos pt-BR
    ├── localService/mainService/    metadata do serviço e dos value helps (categoria, status, moeda), para o mock
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
[`ui5/README.md`](../README.md#sistema-on-premise).

## Validar

```bash
npm run lint        # ESLint (@sap-ux/eslint-plugin-fiori-tools)
npm run build       # ui5 build → dist/
npm run int-test    # OPA5 com o mock server
```

## Deploy

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # build + deploy da BSP ZPC_ESTOQUE
npm run undeploy      # remove a BSP
```

| | SAP BTP, ABAP environment | SAP S/4HANA On-Premise |
| --- | --- | --- |
| `ui5-deploy.yaml` | Como está: URL do sistema, `reentranceTicket`, `transport: ""` (pacotes do `ZLOCAL`) | URL e mandante do sistema, `credentials` por variáveis de ambiente e ordem de transporte Workbench |
| O que é criado | BSP `ZPC_ESTOQUE` e IAM App `ZPC_ESTOQUE_UI5R` | Só a BSP `ZPC_ESTOQUE` |
| Acesso | Tile pelo business catalog (ou tile URL no SAP Build Work Zone) | Catálogo `/UI2/FLPAM` e role `PFCG` |
| URL direta | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_estoque/index.html` | `https://<host>:<porta>/sap/bc/ui5_ui5/sap/zpc_estoque/index.html` |

Configuração On-Premise e conteúdo do launchpad: [`ui5/README.md`](../README.md#sistema-on-premise).
Autorização: objeto `ZPC_ADMIN` (01 criar e importar, 02 alterar, 06 excluir), em
[`abap/README.md`](../../abap/README.md#6-autorização-authority-check-nos-dois-cenários).

---

Gerada com o SAP Fiori Application Generator 1.28.0 (template *List Report Page V4*, OData URL) em
27/09/2026; os dados da geração estão em `.appGenInfo.json`.
