# Pedidos de Compras – SAP RAP / ABAP Cloud

Código-fonte da especificação técnica **v2.0** (três aplicações Fiori Elements desacopladas:
Gestão de Clientes, Gestão de Estoque e Pedidos de Compras) para o **SAP BTP ABAP Environment (Trial)**.

> Os fontes foram escritos para ABAP Cloud (`strict ( 2 )`, `with draft`) e verificados com
> *abaplint* (linguagem **Cloud**: parser ABAP/CDS e checagem de sintaxe). A ativação final
> depende do sistema (release do BTP ABAP). Se o ADT apontar algum ajuste de sintaxe
> específico do release, use o *quick fix* sugerido.

## 1. Estrutura

```
ZPK_PC_PEDIDOS_COMPRAS                 (pacote principal, software component ZLOCAL no trial)
├── 01_ZPK_PC_COMMON     constantes, mensagens, utilitários, ViaCEP, autorização, numeração, CodeLists, setup
├── 02_ZPK_PC_CLIENTES   BO Cliente + Endereço, value helps de cliente/endereço, serviço ZUI_PC_CLIENTES
├── 03_ZPK_PC_ESTOQUE    BO Item, value help de item, serviço ZUI_PC_ESTOQUE
└── 04_ZPK_PC_PEDIDOS    BO Pedido (+ itens, pagamento, snapshots), pagamento simulado, serviço ZUI_PC_PEDIDOS_COMPRAS
```

Convenção de arquivos (um arquivo por objeto ADT):

| Extensão | Objeto no ADT |
|---|---|
| `*.tabl.ddl` | Database Table (editor DDL) |
| `*.ddls.cds` | Data Definition (CDS view entity / projection / abstract entity) |
| `*.ddlx.cds` | Metadata Extension |
| `*.bdef.asbdef` | Behavior Definition |
| `*.srvd.srvdsrv` | Service Definition |
| `*.clas.abap` | Classe global (aba *Global Class*) |
| `*.clas.locals_imp.abap` | Aba *Local Types* da mesma classe (behavior pools) |
| `*.intf.abap` | Interface |
| `zpc_msg.msag.csv` | Conteúdo da Message Class ZPC_MSG (criar manualmente) |

## 2. Objetos criados manualmente (sem código-fonte)

1. **Message Class `ZPC_MSG`** – cadastrar as mensagens 001–041 de `01_ZPK_PC_COMMON/zpc_msg.msag.csv`
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
8. **Business Roles** `ZPC_BR_ADMIN` (três catálogos) e `ZPC_BR_COMUM` (somente `ZPC_BC_PEDIDOS`) – app
   *Maintain Business Roles* (exige administrador; ver seção 5).

## 3. Ordem de criação e ativação

1. Pacotes e objetos manuais 1–4.
2. `ZIF_PC_CONSTANTS`, `ZCX_PC_MSG`, `ZCL_PC_UTIL`, `ZCL_PC_VIACEP`, `ZCL_PC_AUTH`, `ZCL_PC_NUMERACAO`.
3. **Todas** as tabelas ativas `ZA_*` (inclusive `ZA_PC_CODELIST`).
4. CDS base: `ZR_PC_CODELIST` e as 6 value helps de CodeList → `ZR_PC_CLIENTE`/`ZR_PC_ENDERECO`
   (ativar juntas) → `ZR_PC_ITEM` → as 5 views `ZR_PC_*` do pedido (ativar juntas).
5. Abstract entities `ZPC_A_*` e value helps `ZC_PC_*_VALUEHELP`.
6. Tabelas draft `ZD_*` (alternativa: deixar o ADT gerar pelo *quick fix* no BDEF e comparar).
7. Projections `ZC_*_APP` (ativar cada BO em conjunto) e Metadata Extensions.
8. Behavior Definitions `ZR_*` → Behavior Pools `ZBP_R_*` (colar *Global Class* + *Local Types*) → BDEF de projeção `ZC_*`.
9. `ZCL_PC_VE_CLIENTE`, `ZCL_PC_PAGAMENTO_SIM`, `ZCL_PC_SETUP`.
10. Service Definitions → Service Bindings (publicar).
11. Executar `ZCL_PC_SETUP` (F9): cria intervalos de numeração, CodeLists e dados de demonstração.

> Há dependências cruzadas intencionais (ex.: o BO Cliente consulta pedidos para bloquear exclusão).
> Por isso ative primeiro **todas** as tabelas e CDS e só depois os behavior pools.

## 4. Testes rápidos (preview do Service Binding)

| Cenário | Como testar |
|---|---|
| Pagamento aprovado | Cartão `4111 1111 1111 1111` (VISA), validade futura `12/30`, CVV `123` |
| Pagamento recusado | Mesmo cartão com CVV `000` (pedido permanece em AGUARDANDO_PAGAMENTO) |
| Mastercard | Cartão iniciado por `5` (ex.: `5555 5555 5555 4444`) |
| Estoque insuficiente | Pedir mais unidades que a *Qtde disponível* do item |
| Concorrência | Deixar o item em edição (draft) na app de Estoque e confirmar um pedido com ele → `ITEM_ESTOQUE_CONCORRENTE` |
| Exclusão de cliente | Tentar excluir cliente com pedido → bloqueado (`CLIENTE_COM_PEDIDO`) |

Fluxo do pedido: **Criar** (draft) → **Salvar** → **Confirmar pedido** → **Simular pagamento** →
**Aprovar / finalizar** (ou **Cancelar pedido** com motivo).

## 5. Observações sobre o Trial

- `ZIF_PC_CONSTANTS=>c_modo_trial = abap_true` libera as verificações de perfil em `ZCL_PC_AUTH`,
  porque no trial compartilhado normalmente não é possível manter Business Roles nem atribuir
  objetos de autorização ao próprio usuário. **Em um sistema real, defina `abap_false`.**
- ViaCEP: `ZCL_PC_VIACEP` usa `cl_http_destination_provider=>create_by_url` (URL pública). Em produção,
  substitua por *Communication Scenario/Arrangement* (`create_by_comm_arrangement`).
- Aplicações Fiori Elements: gerar no SAP Business Application Studio (template *List Report Page*,
  OData V4) a partir de cada Service Binding; no trial o *preview* do Service Binding já permite o teste completo.
- Os dados do cartão aparecem no diálogo da action (parâmetros da action não possuem máscara em Fiori Elements).
  Eles **não** são persistidos nem logados; apenas bandeira, últimos 4 dígitos e máscara são gravados.
