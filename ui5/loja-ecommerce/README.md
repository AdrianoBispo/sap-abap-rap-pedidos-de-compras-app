# Loja Virtual (e-commerce)

App **SAPUI5 freestyle** (OData V4) que vende os **produtos do estoque** do back-end ABAP
(`ZR_PC_ITEM` / `ZC_PC_ITEM_APP`, serviço `ZUI_PC_ESTOQUE_O4`) e **grava os pedidos e os clientes no mesmo
back-end** (`ZUI_PC_PEDIDOS_COMPRAS_O4` e `ZUI_PC_CLIENTES_O4`). A estrutura e a navegação seguem a app de
demonstração *Shopping Cart* da SAP
([demokit/cart](https://ui5.sap.com/test-resources/sap/m/demokit/cart/webapp/index.html?sap-ui-theme=sap_horizon_dark)):
`FlexibleColumnLayout` com categorias, lista de produtos, detalhe, carrinho em terceira coluna, comparação
de produtos e checkout em *wizard*.

| Item | Valor |
| --- | --- |
| Pasta / `sap.app.id` | `ui5/loja-ecommerce` / `lojaecommerce` |
| Serviços (OData V4) | `ZUI_PC_ESTOQUE_O4` (catálogo, entidade `Item`), `ZUI_PC_PEDIDOS_COMPRAS_O4` (pedido) e `ZUI_PC_CLIENTES_O4` (cadastro de cliente) |
| Tile (inbound) | `ZPCLoja-display` |
| BSP / pacote | `ZPC_LOJA` / `ZAVBS_PC_ESTOQUE` |
| UI5 | 1.136.7 (`sap.f`, `sap.m`, `sap.ui.layout`) |

Largura: a app usa a tela inteira no launchpad (`fullWidth` no `manifest.json` e no componente).

Tema escuro, como no link da demo: abra a app com `?sap-ui-theme=sap_horizon_dark`.

## De onde vêm os dados

O catálogo é lido **uma vez** (`Component.loadCatalog`) com uma lista V4 sobre `/Item`:

- `IsActiveEntity eq true` (a projeção tem rascunho; rascunhos não são vendidos) e `ItemAtivo eq true`
  (item inativo não aparece na loja);
- `$select` só com o necessário, em páginas de 200 itens (`model/Catalog.js`).

| Campo da loja | Origem no back-end |
| --- | --- |
| `ProductId` | `Sku` (chave semântica; vai na URL, `#/category/<id>/product/<sku>`) |
| `Name`, `ShortDescription` | `Nome`, `Descricao` |
| `Category`, `CategoryName` | `Categoria`, `CategoriaTexto` (codelist `CATEGORIA`); as categorias da lateral são montadas dos produtos |
| `Price`, `CurrencyCode` | `PrecoUnitario`, `Currency` |
| `Available` | `QtdeDisponivel` (estoque menos reservas) |
| `Status` | `A` em estoque, `L` últimas unidades (`StatusEstoque = ACABANDO`), `O` sem estoque (`SEM_ESTOQUE` ou quantidade 0) |
| `PictureUrl` | stream `FotoItem` do item ativo, quando há foto (`FotoMimeType`); sem foto, uma imagem SVG gerada com as iniciais e a cor da categoria |

A demo da SAP tem fornecedor, peso e dimensões, e produtos promovidos/mais vistos/favoritos. O estoque do
projeto não tem esses campos; por isso a página de boas-vindas mostra **Produtos em destaque** (2 em estoque,
sorteados), **Últimas unidades** e **Novidades** (por data de criação), e o filtro da categoria usa
disponibilidade e faixa de preço (ordenação por nome ou preço).

## Regras de venda (alinhadas ao back-end)

- Produto **sem estoque** não vai para o carrinho (o back-end bloqueia pedidos com itens sem estoque).
- A quantidade no carrinho nunca passa de `QtdeDisponivel` (campo de quantidade no carrinho e botão de adicionar).
- Ao enviar o pedido o estoque é **lido de novo**. Se um item ficou sem estoque, saiu de venda, teve a
  quantidade reduzida ou mudou de preço, o carrinho é corrigido, o cliente vê o aviso e volta à primeira etapa
  para revisar (`cart.syncWithCatalog`). Depois disso o back-end valida de novo e reserva o estoque.
- Carrinho, itens salvos para depois e comparação ficam no `localStorage` do navegador.

## Login do cliente

O botão da conta (ícone de pessoa, no cabeçalho) abre o login: **CPF + e-mail** ou **CPF + telefone** do cadastro
(`model/AccountService.js`, `controller/Account.js`). A loja lê o cliente ativo pelo CPF no serviço de clientes
(`Cliente`, só `IsActiveEntity` e `ClienteAtivo`) e confere o segundo dado: e-mail sem diferenciar maiúsculas e
espaços; telefone só pelos dígitos (aceita o `+55`). CPF desconhecido e e-mail/telefone errado dão a mesma resposta.
Na sessão (`localStorage`, chave `LOJA_SESSION`) ficam só `ClienteUUID`, CPF, nome, cidade e UF, sem e-mail nem
telefone. O botão passa a mostrar "Olá, <nome>" e abre o menu com **Sair**.

No checkout o cliente logado já vem identificado e **não digita o CPF de novo**. Sem login há três caminhos:
**Entrar** (o botão da etapa), CPF **já cadastrado** (a loja bloqueia e pede o login, o CPF sozinho não vale) ou
CPF **novo** (formulário de cadastro; o cliente é criado ao enviar o pedido e já fica logado).

> [!NOTE]
> Não há senha: quem souber o CPF e o e-mail ou telefone de um cliente entra como ele, e a conferência roda no
> navegador, com a sessão do usuário SAP que abriu a app. É um login simples, não substitui autenticação de
> clientes (por exemplo, IAS) numa loja aberta ao público.

## Pedido gravado no back-end

O checkout usa o mesmo fluxo de rascunho (*draft*) das apps de gestão, pelas actions OData dos serviços
(`model/OrderService.js`, `model/CustomerService.js`):

1. **Cliente**: o logado (CPF + e-mail/telefone) ou, na primeira compra, um CPF novo. O pedido é entregue no
   **endereço principal** do cadastro. Para o CPF novo a loja mostra o formulário de cadastro e o
   cliente é criado ao enviar o pedido, no serviço `ZUI_PC_CLIENTES_O4`: rascunho do `Cliente` + `_Endereco`
   (CEP e número; o back-end completa o endereço pelo CEP e o torna o principal), `Prepare` e `Activate`.
2. **Pedido**: `POST Pedido` (rascunho com `ClienteUUID` e a observação), `POST Pedido/_Itens` para cada item,
   `Prepare` (valida cliente, endereço principal, itens e estoque) e `Activate`. A ativação reserva o estoque,
   dá o **número do pedido** e deixa o pedido `ABERTO`. Se algum passo falha, o rascunho é descartado
   (`Discard`) e a mensagem do back-end aparece para o cliente. As actions de rascunho vão com `If-Match: *`
   (`Backend.invoke`): o ETag do rascunho muda a cada item criado, e com o ETag da criação o `Prepare` dava
   `412 stale If-Match`, o pedido ficava como rascunho e o `Discard` falhava do mesmo jeito.
3. **Pagamento**: action `SimularPagamento` (método `CARTAO_CREDITO`/`CARTAO_DEBITO`, número, validade MM/AA,
   CVV). O back-end não guarda os dados do cartão. Aprovado, o pedido vai para `AGUARDANDO_APROVACAO` e a loja
   mostra o número. **Recusado** (no simulador, CVV `000`) não é erro: o pedido continua aberto e uma nova
   tentativa só paga o mesmo pedido. Se o cliente desiste, `CancelarPedido` cancela e libera o estoque.

O `Pedido` não tem campo para o tipo de entrega: ele vai na observação (`Loja virtual | Entrega expressa | ...`).
A aprovação do pedido e o reembolso continuam nas apps de gestão. O usuário logado precisa das autorizações
`ZPC_PEDIDO` de criar e executar (a mesma da app Pedidos de Compras).

## Checkout

Etapas: itens → identificação (cliente logado, ou CPF + cadastro quando o CPF é novo: nome, e-mail, telefone, data de nascimento,
CEP, número, complemento) → forma de pagamento (**cartão de crédito** ou **débito**) → dados do cartão → tipo de
entrega (padrão ou expressa) e observações → resumo. Os campos são validados no cliente (`model/types/`) e de novo
pelo back-end; o resumo mostra só os 4 últimos dígitos do cartão.

## Estrutura

```
loja-ecommerce/
├── package.json, ui5*.yaml      scripts, proxy /sap (reentranceTicket), mock server, deploy (BSP ZPC_LOJA)
└── webapp/
    ├── Component.js             modelos (catálogo, carrinho, comparação, device) e loadCatalog()
    ├── manifest.json            serviço V4, rotas do FlexibleColumnLayout, inbound do tile
    ├── model/Catalog.js         leitura do /Item e conversão em produto, categorias e imagem gerada
    ├── model/cart.js            adicionar ao carrinho, limite de estoque, conferência com o catálogo
    ├── model/OrderService.js    busca do cliente, pedido (rascunho, itens, Prepare, Activate), pagamento e cancelamento
    ├── model/CustomerService.js cadastro do cliente novo (rascunho, endereço, Prepare, Activate)
    ├── model/Backend.js         texto de erro do OData, bind de actions e descarte de rascunho
    ├── model/formatter.js       preço pt-BR, status, totais
    ├── model/AccountService.js  login por CPF + e-mail/telefone
    ├── controller/Account.js    diálogo de login e menu da conta
    ├── model/types/             validação de CPF e e-mail
    ├── controller/ view/        App, Home, Welcome, Category, Product, Comparison, Cart, Checkout, OrderCompleted
    ├── i18n/                    textos pt-BR
    ├── localService/            metadata dos 3 serviços e dados do mock (100 itens, 2 clientes, regras do pedido)
    └── test/unit/               QUnit: catálogo, carrinho, CPF, formatter e o fluxo do pedido contra o mock
```

## Executar

```bash
cd ui5/loja-ecommerce
npm install
npm run start-mock-noflp   # dados de demonstração e pedidos simulados, sem backend (http://localhost:8080/index.html)
npm start                  # dados reais, pelo proxy do BTP (o navegador abre o login na primeira chamada)
npm run unit-test          # testes QUnit
npm run lint && npm run build
npm run deploy-test        # simula o deploy; npm run deploy grava a BSP ZPC_LOJA
```

O mock usa o `$metadata` do serviço de estoque e 100 itens iguais aos que `ZCL_SETUP_ESTOQUE` cria
(25 produtos-base × 4 linhas; 5 sem estoque, 5 acabando; o último inativo, para mostrar que não aparece na loja).
Os três serviços usam o `$metadata` baixado do sistema (07/10/2026); os de pedidos e de clientes usam o
rascunho/`Activate` do mock server; `localService/ordersService/data/Pedido.js` imita a numeração, o status e as
actions `SimularPagamento` e `CancelarPedido` (CVV `000` recusa), e `customersService/data/*.js` imitam o
preenchimento do endereço pelo CEP. CPFs de teste: `529.982.247-25` (cadastrada; e-mail `maria@exemplo.com.br`, telefone `(81) 99999-0000`) e `390.533.447-05` (novo).
Para atualizar os `metadata.xml` depois de mudar um serviço: `npm start` (login do SAP ID no navegador) e salve o `$metadata` de cada serviço, por exemplo
`curl http://localhost:8080/sap/opu/odata4/sap/zui_pc_pedidos_compras_o4/srvd/sap/zui_pc_pedidos_compras/0001/\$metadata`.
Depois do deploy a loja abre em
`https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_loja/index.html`.
