# Pedidos de Compras – SAP RAP / ABAP Cloud

Código-fonte das três aplicações Fiori Elements desacopladas Gestão de Clientes, Gestão de Estoque e Pedidos de Compras para o **SAP BTP ABAP Environment (Trial)**: backend RAP em `abap/` e front-end SAP Fiori Elements (OData V4) em `ui5/`.

> Os fontes foram escritos para ABAP Cloud (`strict ( 2 )`, `with draft`) e verificados com
> *abaplint* (linguagem **Cloud**: parser ABAP/CDS e checagem de sintaxe). A ativação final
> depende do sistema (release do BTP ABAP). Se o ADT apontar algum ajuste de sintaxe
> específico do release, use o *quick fix* sugerido.

## 1. Estrutura

```
projeto/
├── abap/ backend ABAP Cloud / RAP
|    └── ZPK_PC_PEDIDOS_COMPRAS   (pacote principal, software component ZLOCAL no trial)
|        ├── 01_ZPK_PC_COMMON     constantes, mensagens, utilitários, ViaCEP, autorização, numeração, CodeLists, setup
|        ├── 02_ZPK_PC_CLIENTES   BO Cliente + Endereço, value helps de cliente/endereço, serviço ZUI_PC_CLIENTES
|        ├── 03_ZPK_PC_ESTOQUE    BO Item, value help de item, serviço ZUI_PC_ESTOQUE
|        └── 04_ZPK_PC_PEDIDOS    BO Pedido (+ itens, pagamento, snapshots), pagamento simulado, serviço ZUI_PC_PEDIDOS_COMPRAS
|
├── ui5/ front-end Fiori Elements: apps clientes/, estoque/ e pedidos/
|     ├── clientes  Arquivos UI5 para o app de Clientes
|     ├── estoque   Arquivos UI5 para o app de Estoque
|     ├── pedidos   Arquivos UI5 para o app de Pedidos de Compras
|     └── README.md
|
└── README.md
```

Convenção de arquivos (um arquivo por objeto ADT):

| Extensão                 | Objeto no ADT                                                    |
| ------------------------ | ---------------------------------------------------------------- |
| `*.tabl.ddl`             | Database Table (editor DDL)                                      |
| `*.ddls.cds`             | Data Definition (CDS view entity / projection / abstract entity) |
| `*.ddlx.cds`             | Metadata Extension                                               |
| `*.bdef.asbdef`          | Behavior Definition                                              |
| `*.srvd.srvdsrv`         | Service Definition                                               |
| `*.clas.abap`            | Classe global (aba *Global Class*)                               |
| `*.clas.locals_imp.abap` | Aba *Local Types* da mesma classe (behavior pools)               |
| `*.intf.abap`            | Interface                                                        |
| `zpc_msg.msag.csv`       | Conteúdo da Message Class ZPC_MSG (criar manualmente)            |

## 2. Objetos criados manualmente (sem código-fonte)

1. **Message Class `ZPC_MSG`** – cadastrar as mensagens 001–047 de `01_ZPK_PC_COMMON/zpc_msg.msag.csv`
   (limite de 73 caracteres por texto; `&1`/`&2` são parâmetros).
2. **Domínio `ZPC_NR_NUMC10`** – NUMC, tamanho 10 (usado como *Number Length Domain*).
3. **Number Range Object `ZPC_NR`** – domínio `ZPC_NR_NUMC10`, sem subobjeto.
   Os intervalos 01 (pedido) e 02 (SKU) são criados pela classe `ZCL_PC_SETUP`.
4. **Authorization Objects** (campo `ACTVT`): `ZPC_ADMIN` e `ZPC_PEDIDO`.
5. **Service Bindings** (OData V4 – UI): `ZUI_PC_CLIENTES_O4`, `ZUI_PC_ESTOQUE_O4`,
   `ZUI_PC_PEDIDOS_COMPRAS_O4` → **Publish**.
6. **IAM Apps** `ZPC_IAM_CLIENTES`, `ZPC_IAM_ESTOQUE`, `ZPC_IAM_PEDIDOS` (o ADT acrescenta o sufixo `_EXT`),
   com o serviço correspondente e os objetos de autorização.
7. **Business Catalogs** `ZPC_BC_CLIENTES`, `ZPC_BC_ESTOQUE`, `ZPC_BC_PEDIDOS` (um por IAM App).
   Depois do deploy do front-end, cada catálogo recebe também o IAM App do tile
   (`ZPC_CLIENTES_UI5R`, `ZPC_ESTOQUE_UI5R`, `ZPC_PEDIDOS_UI5R`) – seção 7.
8. **Business Roles** `ZPC_BR_ADMIN` (três catálogos) e `ZPC_BR_COMUM` (somente `ZPC_BC_PEDIDOS`) – app
   *Maintain Business Roles* (exige administrador; ver seção 5).
9. **Índices secundários únicos** (garantia de unicidade no banco — a validation sozinha não
   protege contra duas ativações simultâneas):

   | Tabela            | Campos         | Único |
   | ----------------- | -------------- | :---: |
   | `ZTA_PC_CLIENTE`  | `CPF`          |  sim  |
   | `ZTA_PC_ITEM`     | `SKU`          |  sim  |
   | `ZTA_PC_ITEM_PED` | `ITEM_UUID`    |  não  |
   | `ZTA_PC_PEDIDO`   | `CLIENTE_UUID` |  não  |
   | `ZTA_PC_ENDERECO` | `CLIENTE_UUID` |  não  |

   No ADT: abrir a tabela → *Add Index* (ou *New → ABAP Dictionary → Database Index*, conforme o
   release). Os três últimos são de desempenho (feature control e checagens de vínculo).

## 3. Ordem de criação e ativação

1. Pacotes e objetos manuais 1–4.
2. `ZIF_PC_CONSTANTS`, `ZCX_PC_MSG`, `ZCL_PC_UTIL`, `ZCL_PC_VIACEP`, `ZCL_PC_AUTH`, `ZCL_PC_NUMERACAO`.
3. **Todas** as tabelas ativas `ZTA_*` (inclusive `ZTA_PC_CODELIST`).
4. CDS base: `ZI_PC_CODELIST` e as 6 value helps de CodeList → `ZR_PC_CLIENTE`/`ZR_PC_ENDERECO`
   (ativar juntas) → `ZR_PC_ITEM` → as 5 views `ZR_PC_*` do pedido (ativar juntas).
5. Abstract entities `ZPC_A_*` e value helps `ZC_PC_*_VALUEHELP`. A custom entity `ZI_PC_CEP_LOOKUP` e
   a classe `ZCL_PC_CEP_LOOKUP_PROVIDER` referenciam uma à outra: ativar as duas juntas.
6. Tabelas draft `ZD_*` (alternativa: deixar o ADT gerar pelo *quick fix* no BDEF e comparar).
   `ZD_PC_ENDERECO` precisa ter `CONSULTEDCEP`: se ela já existia, use *Ctrl+1 → Update draft table*
   sobre `zd_pc_endereco` no BDEF `ZR_PC_CLIENTE`.
7. Projections `ZC_*_APP` (ativar cada BO em conjunto) e Metadata Extensions.
8. Behavior Definitions `ZR_*` → Behavior Pools `ZBP_R_*` (colar *Global Class* + *Local Types*) → BDEF de projeção `ZC_*`.
9. `ZCL_PC_VE_CLIENTE`, `ZCL_PC_PAGAMENTO_SIM`, `ZCL_PC_SETUP`.
10. Service Definitions → Service Bindings (publicar).
11. Executar `ZCL_PC_SETUP` (F9): cria intervalos de numeração, CodeLists e dados de demonstração, e marca
    como consultados (`CONSULTED_CEP = CEP`) os endereços gravados antes da seção 8.
12. Front-end: `cd ui5 && npm install && npm run set-backend -- <URL do sistema>` → testar com
    `npm run start:launchpad` → `npm run deploy` → incluir os IAM Apps `*_UI5R` nos Business Catalogs
    (seção 7).

> Há dependências cruzadas intencionais (ex.: o BO Cliente consulta pedidos para bloquear exclusão).
> Por isso ative primeiro **todas** as tabelas e CDS e só depois os behavior pools.

## 4. Testes rápidos (preview do Service Binding ou apps em `ui5/`)

| Cenário              | Como testar                                                                                                  |
| -------------------- | ------------------------------------------------------------------------------------------------------------ |
| Pagamento aprovado   | Cartão `4111 1111 1111 1111` (VISA), validade futura `12/30`, CVV `123`                                      |
| Pagamento recusado   | Mesmo cartão com CVV `000` (pedido permanece em AGUARDANDO_PAGAMENTO)                                        |
| Mastercard           | Cartão iniciado por `5` (ex.: `5555 5555 5555 4444`)                                                         |
| Estoque insuficiente | Pedir mais unidades que a *Qtde disponível* do item                                                          |
| Concorrência         | Deixar o item em edição (draft) na app de Estoque e confirmar um pedido com ele → `ITEM_ESTOQUE_CONCORRENTE` |
| Exclusão de cliente  | Tentar excluir cliente com pedido → bloqueado (`CLIENTE_COM_PEDIDO`)                                         |

Fluxo do pedido: **Criar** (draft) → **Salvar** → **Confirmar pedido** → **Simular pagamento** →
**Aprovar / finalizar** (ou **Cancelar pedido** com motivo).

## 5. Observações sobre o Trial

- `ZIF_PC_CONSTANTS=>c_modo_trial` vem como **`abap_false` (seguro por padrão)**: todas as operações
  exigem os objetos de autorização `ZPC_ADMIN` / `ZPC_PEDIDO`. No trial compartilhado, onde não é
  possível manter Business Roles, altere para `abap_true` **apenas nesse sistema** — com `abap_true`
  qualquer usuário com acesso ao serviço age como administrador.
- `ZCL_PC_AUTH` verifica a atividade correspondente a cada operação: `01` criar, `02` alterar,
  `06` excluir, `16` executar (actions do pedido).
- ViaCEP: `ZCL_PC_VIACEP` usa `cl_http_destination_provider=>create_by_url` (URL pública). Em produção,
  substitua por *Communication Scenario/Arrangement* (`create_by_comm_arrangement`).
- Aplicações Fiori Elements: prontas em `ui5/` (seção 7). O *preview* do Service Binding continua útil
  para testar o backend isoladamente, mas não tem launchpad nem navegação entre apps.
- O trial é compartilhado e não permite manter Business Roles (ver acima). Nele, o deploy das apps
  funciona, mas os tiles só aparecem para quem tiver as roles. Use o launchpad local
  (`npm run start:launchpad`) para o teste completo.
- Os dados do cartão aparecem no diálogo da action (parâmetros da action não possuem máscara em Fiori Elements).
  Eles **não** são persistidos nem logados; apenas bandeira, últimos 4 dígitos e máscara são gravados.

## 6. Correções do code review (v1.1)

| #   | Correção                                                                                                        | Objetos                                                                       |
| --- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| B1  | `/UI2/CL_JSON` (API não liberada) substituída por extração via PCRE; alternativa XCO documentada no cabeçalho   | `ZCL_PC_VIACEP`                                                               |
| B2  | Chamada ao ViaCEP sai da fase de save: a determination grava `CepStatus` (V/I/X) e a validation apenas o avalia | `ZBP_R_PC_CLIENTE`, `ZTA_PC_ENDERECO`, `ZR_PC_ENDERECO`, `ZC_PC_ENDERECO_APP` |
| B3  | Toda chamada EML avalia `FAILED`/`REPORTED`; compensação de reserva e snapshots propagam erro                   | 3 behavior pools                                                              |
| B4  | Índices únicos de `CPF` e `SKU` documentados como objeto manual (seção 2.9)                                     | README                                                                        |
| B5  | `c_modo_trial` passa a `abap_false`; verificação por atividade (01/02/06/16)                                    | `ZIF_PC_CONSTANTS`, `ZCL_PC_AUTH`, 3 behavior pools                           |
| R4  | Cliente HTTP fechado também em caminho de erro                                                                  | `ZCL_PC_VIACEP`                                                               |
| R6  | `CATCH cx_root` eliminado                                                                                       | `ZCL_PC_VIACEP`                                                               |
| R7  | Cache do ViaCEP limitado a 100 entradas                                                                         | `ZCL_PC_VIACEP`                                                               |

Testes unitários (ABAP Unit) das regras puras acompanham as classes:
`ZCL_PC_UTIL` e `ZCL_PC_PAGAMENTO_SIM` (arquivos `*.clas.testclasses.abap`).

## 7. Front-end Fiori (`ui5/`)

Três apps **Fiori Elements OData V4** (List Report + Object Page), uma por serviço. O guia completo está
em [`ui5/README.md`](ui5/README.md).

| App                | Pasta          | Serviço                     | Páginas                            | Tile (semantic object)   | BSP            |
| ------------------ | -------------- | --------------------------- | ---------------------------------- | ------------------------ | -------------- |
| Gestão de Clientes | `ui5/clientes` | `ZUI_PC_CLIENTES_O4`        | Cliente → Endereço                 | `ZPCCliente-manage`      | `ZPC_CLIENTES` |
| Gestão de Estoque  | `ui5/estoque`  | `ZUI_PC_ESTOQUE_O4`         | Item                               | `ZPCItemEstoque-manage`  | `ZPC_ESTOQUE`  |
| Pedidos de Compras | `ui5/pedidos`  | `ZUI_PC_PEDIDOS_COMPRAS_O4` | Pedido → Item / Histórico de itens | `ZPCPedidoCompra-manage` | `ZPC_PEDIDOS`  |

```bash
cd ui5
npm install
npm run set-backend -- https://<id>.abap.<região>.hana.ondemand.com
npm run start:launchpad     # launchpad local com os três tiles e navegação entre apps
npm run lint && npm run build
npm run deploy              # BSP + IAM App <BSP>_UI5R em cada pacote ZPK_PC_*
```

Requisitos e notas:

- Node.js 20+ e SAP Fiori tools (BAS ou VS Code). O launchpad do sistema precisa de **SAPUI5 1.136 ou
  superior**, porque o `manifest.json` usa descriptor versão 2.
- **Depois do deploy.** Incluir `ZPC_*_UI5R` nos Business Catalogs `ZPC_BC_*` e publicar. Montar um
  espaço/página em *Manage Launchpad Spaces* e atribuí-lo às Business Roles `ZPC_BR_ADMIN` e
  `ZPC_BR_COMUM`.
- **Validação.** As três apps passam no `ui5 build` e no UI5 linter (sem achados). Os manifests
  validam contra o schema oficial do descriptor v2. O teste contra o backend real depende do seu
  sistema BTP.

Ajustes no backend feitos para o front-end (v1.2):

| Ajuste                                                                                                                                                                                                           | Objetos                                     |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| Semantic objects para navegação entre apps: `ZPCCliente` em `ClienteUUID`/`NomeCliente` e `ZPCItemEstoque` em `ItemUUID`/`Sku`                                                                                   | `ZC_PC_PEDIDO_APP`, `ZC_PC_ITEM_PEDIDO_APP` |
| Seções *Pagamento* e *Histórico - cliente* passam de `#LINEITEM_REFERENCE` para `#IDENTIFICATION_REFERENCE`: as composições são `[0..1]`, e Fiori Elements V4 só monta tabela para navegações de cardinalidade N | `ZC_PC_PEDIDO_APP` (MDE)                    |

## 8. Endereço do cliente: consulta de CEP (v1.3)

O CRUD do Endereço (filho de composição de `Cliente`) segue a mesma lógica da aplicação
`sap-abap-enderecos-viacep`. O BO não chama mais o ViaCEP: a consulta sai da determination e passa
para uma custom entity que a UI lê.

1. Na Object Page do Endereço, a seção **Consulta de CEP** (extensão SAPUI5 em
   `ui5/clientes/webapp/ext/`) aplica a máscara `99999-999` e grava o CEP normalizado no draft.
2. A determination `LimparDadosCep` (on modify, campo `Cep`) apaga logradouro, complemento, bairro,
   cidade, UF, estado, `CepGeral`, `CepStatus` e `ConsultedCep` sempre que o CEP deixa de ser o
   consultado.
3. A UI lê `CepLookUp` (`ZI_PC_CEP_LOOKUP` → `ZCL_PC_CEP_LOOKUP_PROVIDER` → `ZCL_PC_VIACEP`). A
   leitura nunca falha por CEP ruim: devolve `Status` `V` (validado), `I` (inválido/inexistente) ou
   `X` (ViaCEP indisponível).
4. A UI chama a ação `AplicarDadosCep` (parâmetro `ZPC_A_CEP_RESULTADO`, `result [1] $self`), que
   grava o resultado e `ConsultedCep`. Resultados com falha também são gravados, com os campos
   automáticos limpos.
5. `ValidarCep` (on save, sem I/O remoto) bloqueia a ativação quando o CEP tem formato inválido,
   `CepStatus` é `I`/`X`/vazio, `ConsultedCep <> Cep`, ou o CEP é geral de município sem
   logradouro/bairro.

Campos: cidade, UF, estado e os técnicos são somente leitura. Logradouro e bairro continuam com
feature control (editáveis e obrigatórios só para CEP geral). Complemento e número ficam livres.

Detalhes que costumam morder:

- **Cardinalidade da ação.** Toda chave de `AplicarDadosCep` precisa sair em `result` ou em
  `failed`. Uma chave que não aparece em nenhum dos dois faz o runtime OData abortar com
  `RAISE_SHORTDUMP`. O caso típico é o draft ativado ou descartado com a chamada ainda em voo
  (mensagem 047).
- **Rajada de requisições.** O handler usa debounce de 700 ms e um token de sequência que descarta
  respostas fora de ordem. O backend ainda confere se o resultado corresponde ao CEP gravado no
  draft (mensagem 042).
- **`@UI.hidden` não é cosmético.** `CepStatus` e `ConsultedCep` ficam fora do `$select` da Object
  Page. O handler usa `requestProperty()` para lê-los.
- **CEP na tabela de endereços.** A coluna "CEP" da tabela do cliente é `ConsultedCep`, que é somente
  leitura. Uma coluna `Cep` editável em modo de edição mudaria o CEP sem consulta.
- **Namespace da ação.** `CepUtil.js` descobre o namespace do serviço em runtime (`/$EntityContainer`).
  Os caminhos de módulo do fragmento usam `zpc/clientes`, que precisa bater com `sap.app.id`.

Testes da extensão: `ui5/clientes/webapp/test/testsuite.qunit.html` (UI5 Test Starter).
