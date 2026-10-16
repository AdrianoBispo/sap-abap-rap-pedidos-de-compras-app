# Tutorial: Controle de leitura nas CDS Views com Access Control (DCL)

> **Implementação opcional.** Este roteiro complementa o
> [tutorial de autorização On-Premise](tutorial_autorizacao_btp_para_onpremise.md) e vale para o
> **SAP BTP ABAP Environment** e para o **SAP S/4HANA On-Premise**. Ative-o somente onde for possível atribuir
> os objetos de autorização aos usuários (ver [seção 3](#3-pré-requisitos)).

## 1. Objetivo

Hoje o projeto controla **escrita** (criar, alterar, excluir e executar ações) com `AUTHORITY-CHECK` em
`ZCL_PC_AUTH`, chamado pelos métodos `get_global_authorizations` dos behavior pools. A **leitura** não é
controlada: todas as CDS Views estão com

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
```

e não existe nenhuma regra de acesso (DCL). Na prática, qualquer usuário com acesso a um serviço OData consegue
**listar e ler todos os registros** dele — clientes (CPF, e-mail, telefone, endereços), pagamentos (cartão
mascarado), reembolsos e as análises.

Este tutorial mostra como exigir a atividade **03 (Exibir)** dos objetos `ZPC_ADMIN` e `ZPC_PEDIDO` para ler
os dados, usando **CDS Access Control** (DCL — *Data Control Language*):

1. criar uma regra de acesso (`define role`) para cada view exposta nos serviços;
2. trocar a anotação das views para `#CHECK`;
3. incluir a atividade 03 nas roles dos usuários;
4. testar e diagnosticar.

---

## 2. Como funciona

### 2.1. Escrita × leitura no RAP

| Operação                          | Onde é verificada                                 | Mecanismo                         |
| --------------------------------- | ------------------------------------------------- | --------------------------------- |
| Criar, alterar, excluir, ações    | `get_global_authorizations` (behavior pool)       | `AUTHORITY-CHECK` (`ZCL_PC_AUTH`) |
| Ler (lista, Object Page, análises, value helps) | Banco de dados, no `SELECT` da CDS View | **Access Control (DCL)**          |

O RAP **não** chama o behavior pool para as consultas (*queries*) do OData: a lista, a Object Page, os value
helps e o `$apply` das análises viram um `SELECT` na CDS View exposta. Por isso o `AUTHORITY-CHECK` não protege
a leitura — quem protege é a DCL, que o ABAP acrescenta automaticamente como condição `WHERE` em todo `SELECT`
feito sobre a view.

### 2.2. A regra de acesso

```abap
@EndUserText.label: 'Acesso aos pedidos de compra'
@MappingRole: true
define role ZC_PC_PEDIDO_APP {
  grant select on ZC_PC_PEDIDO_APP
    where ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '03' );
}
```

- `grant select on <view>` — a regra vale para essa view.
- `aspect pfcg_auth( <objeto>, <campos>, ACTVT = '03' )` — consulta as autorizações do usuário (as mesmas da
  role `PFCG` ou da Business Role do BTP).
- `( ) = aspect pfcg_auth(...)` — lista vazia de elementos: a condição é **tudo ou nada**. Se o usuário tem
  `ZPC_PEDIDO` com `ACTVT = 03`, vê todos os registros; se não tem, vê **zero** registros (sem mensagem de
  erro).
- Com elementos na lista (ex.: `( UfPrincipal ) = aspect pfcg_auth( ZPC_ADMIN, ZPC_UF, ACTVT = '03' )`) a
  regra filtra **linha a linha** pelo valor autorizado (ver [seção 6](#6-variações-filtro-por-linha)).

### 2.3. A anotação da view

| Valor de `@AccessControl.authorizationCheck` | Efeito                                                                  |
| -------------------------------------------- | ----------------------------------------------------------------------- |
| `#NOT_REQUIRED` (atual)                      | Aplica a DCL se existir; sem aviso se não existir                       |
| `#CHECK` (recomendado)                       | Aplica a DCL; **aviso de sintaxe** se a view não tiver regra de acesso  |
| `#NOT_ALLOWED`                               | Ignora qualquer DCL (nunca use em view exposta)                         |

> Repare: com `#NOT_REQUIRED` a DCL **já é aplicada** se existir. Trocar para `#CHECK` serve para documentar a
> intenção e fazer o ADT avisar quando uma view exposta ficar sem regra.

### 2.4. Onde colocar as regras: camada de consumo

As regras ficam **somente nas views expostas nos serviços** (`ZC_*`). As views da camada R (`ZR_*`) e os cubos
(`ZI_*_CUBE`) continuam sem DCL. O motivo está no próprio código dos behavior pools, que faz `SELECT` direto
nas views `ZR_*`:

| Behavior pool         | Lê por ABAP SQL                                           | Para quê                                   |
| --------------------- | --------------------------------------------------------- | ------------------------------------------ |
| `ZBP_R_PC_PEDIDO`     | `zr_pc_cliente`, `zr_pc_endereco`, `zr_pc_item`, `zr_pc_item_pedido`, `zr_pc_pedido` | Validar cliente ativo, endereço, estoque e referência de importação |
| `ZBP_R_PC_CLIENTE`    | `zr_pc_endereco`, `zr_pc_pedido`, `zr_pc_codelist`        | Endereço principal, CEP já cadastrado, pedidos do cliente |
| `ZBP_R_PC_ITEM`       | `zr_pc_codelist`                                          | Textos e prefixos de categoria             |

Se a DCL fosse colocada em `ZR_PC_CLIENTE` ou `ZR_PC_ITEM`, um usuário que só tem `ZPC_PEDIDO` teria esses
`SELECT` filtrados e **não conseguiria criar pedidos** (o cliente "não existiria" e o estoque "estaria zerado").
Mantendo a camada R sem DCL, as regras de negócio continuam enxergando todos os dados e só a leitura feita pelo
usuário, pelo serviço, é filtrada.

> Se no futuro você quiser proteger também a camada R, acrescente `WITH PRIVILEGED ACCESS` em cada `SELECT`
> interno dos behavior pools (ex.: `SELECT ... FROM zr_pc_cliente WITH PRIVILEGED ACCESS ...`).

---

## 3. Pré-requisitos

- `ZIF_PC_CONSTANTS=>c_modo_trial = abap_false` — a DCL **não** respeita o modo trial: `pfcg_auth` sempre
  consulta as autorizações reais do usuário.
- Atividade **03 (Exibir)** nos objetos `ZPC_ADMIN` e `ZPC_PEDIDO` (já existe nos dois `.susob.xml`).
- Possibilidade de atribuir a atividade 03 aos usuários:
  - **BTP:** Business Roles com restrição de leitura nos objetos (não disponível no BTP Trial compartilhado);
  - **On-Premise:** roles `PFCG` (`Z_PC_ADMIN` / `Z_PC_COMUM`).

> **Não ative no BTP Trial.** Sem Business Roles configuráveis ninguém recebe `ACTVT = 03`, e todas as listas,
> Object Pages, value helps e análises passam a voltar **vazias**.

---

## 4. Mapa das regras

Os cinco serviços expõem 25 views. A tabela abaixo define a regra de cada uma:

| Serviço                    | View exposta               | Entity set          | Regra de leitura                                    |
| -------------------------- | -------------------------- | ------------------- | --------------------------------------------------- |
| `ZUI_PC_CLIENTES`          | `ZC_PC_CLIENTE_APP`        | `Cliente`           | `ZPC_ADMIN` 03                                      |
|                            | `ZC_PC_ENDERECO_APP`       | `Endereco`          | `ZPC_ADMIN` 03                                      |
|                            | `ZC_PC_CEP_VH`             | `CepVH`             | `ZPC_ADMIN` 01 **ou** 02 (quem cadastra endereços)  |
|                            | `ZC_PC_GENERO_VH`          | `GeneroVH`          | sem regra (lista de códigos)                        |
| `ZUI_PC_ESTOQUE`           | `ZC_PC_ITEM_APP`           | `Item`              | `ZPC_ADMIN` 03                                      |
|                            | `ZC_PC_CATEGORIA_VH`, `ZC_PC_STATUSEST_VH` | —   | sem regra (listas de códigos)                       |
|                            | `I_CurrencyStdVH`          | `CurrencyVH`        | da SAP (já protegida pela SAP)                      |
| `ZUI_PC_PEDIDOS_COMPRAS`   | `ZC_PC_PEDIDO_APP`         | `Pedido`            | `ZPC_PEDIDO` 03                                     |
|                            | `ZC_PC_ITEM_PEDIDO_APP`    | `ItemPedido`        | `ZPC_PEDIDO` 03                                     |
|                            | `ZC_PC_PAGAMENTO_APP`      | `Pagamento`         | `ZPC_PEDIDO` 03                                     |
|                            | `ZC_PC_PED_CLI_SNAP_APP`   | `ClienteSnapshot`   | `ZPC_PEDIDO` 03                                     |
|                            | `ZC_PC_PED_ITEM_SNAP_APP`  | `ItemSnapshot`      | `ZPC_PEDIDO` 03                                     |
|                            | `ZC_PC_CLIENTE_VH`         | `ClienteVH`         | `ZPC_ADMIN` 03 **ou** `ZPC_PEDIDO` 01 **ou** 02     |
|                            | `ZC_PC_ENDERECO_VH`        | `EnderecoVH`        | `ZPC_ADMIN` 03 **ou** `ZPC_PEDIDO` 01 **ou** 02     |
|                            | `ZC_PC_ITEM_VH`            | `ItemVH`            | `ZPC_ADMIN` 03 **ou** `ZPC_PEDIDO` 01 **ou** 02     |
|                            | `ZC_PC_STATUSPED_VH`, `ZC_PC_STATUSPAG_VH`, `ZC_PC_METODOPAG_VH` | — | sem regra (listas de códigos) |
| `ZUI_PC_REEMBOLSOS`        | `ZC_PC_REEMBOLSO_APP`      | `Reembolso`         | `ZPC_PEDIDO` 03                                     |
|                            | `ZC_PC_STATUSREEMB_VH`     | `StatusReembolsoVH` | sem regra (lista de códigos)                        |
| `ZUI_PC_ANALITICO`         | `ZC_PC_PEDIDO_ANALISE`     | `PedidoAnalise`     | `ZPC_PEDIDO` 03                                     |
|                            | `ZC_PC_REEMB_ANALISE`      | `ReembolsoAnalise`  | `ZPC_PEDIDO` 03                                     |
|                            | `ZC_PC_CLIENTE_ANALISE`    | `ClienteAnalise`    | `ZPC_ADMIN` 03                                      |
|                            | `ZC_PC_ITEM_ANALISE`       | `ItemAnalise`       | `ZPC_ADMIN` 03                                      |

Decisões importantes:

- **Toda entidade exposta precisa da sua própria regra**, inclusive as filhas. Proteger só `ZC_PC_PEDIDO_APP`
  não basta: `GET .../ItemPedido` ou `GET .../Pagamento` leem as filhas diretamente pelo entity set.
- **Value helps do pedido** aceitam quem lê cadastros (`ZPC_ADMIN` 03) **ou** quem cria/altera pedidos
  (`ZPC_PEDIDO` 01/02). Sem isso, um usuário que só opera pedidos não conseguiria escolher cliente, endereço e
  item.
- **Campos do cliente dentro do pedido** (`NomeCliente`, `CpfCliente`, `EmailCliente`...) vêm por path
  expression da camada R e **continuam visíveis** para quem lê o pedido, mesmo sem `ZPC_ADMIN` 03. É o
  comportamento esperado: são dados do pedido. Já o link para a app Gestão de Clientes abrirá vazio para esse
  usuário.
- **Listas de códigos** (`*_VH` de status, gênero, categoria, método de pagamento) não têm dados de negócio e
  ficam sem regra (`#NOT_REQUIRED`).

---

## 5. Passo a passo

### Passo 1 — Criar a regra de acesso no ADT

Para cada view com regra na tabela da seção 4:

1. No ADT, clique com o botão direito na view (ex.: `ZC_PC_PEDIDO_APP`) → **New Access Control**.
   (ou *New → Other ABAP Repository Object → Core Data Services → Access Control*).
2. **Name:** o mesmo nome da view (ex.: `ZC_PC_PEDIDO_APP`); **Description:** *Acesso aos pedidos de compra*.
3. **Package:** o mesmo pacote da view (`ZAVBS_PC_PEDIDOS`, `ZAVBS_PC_CLIENTES`, `ZAVBS_PC_ESTOQUE`,
   `ZAVBS_PC_REEMBOLSOS` ou `ZAVBS_PC_COMMON`).
4. Template: **Define Role with PFCG Aspect**.
5. Substitua o conteúdo pela regra correspondente (seção 5.4) e **ative** (`Ctrl+F3`).

### Passo 2 — Trocar a anotação das views protegidas

Nas mesmas views, troque:

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
```

por:

```abap
@AccessControl.authorizationCheck: #CHECK
```

e ative. Deixe `#NOT_REQUIRED` nas views `ZR_*`, `ZI_*_CUBE`, nos value helps de códigos e nas abstract
entities `ZPC_A_*`.

> Ative **regras e views juntas** (*Activate All*, `Ctrl+Shift+F3`) para não ficar com view `#CHECK` sem regra.

### Passo 3 — Incluir a atividade 03 nas roles

**SAP BTP ABAP Environment**

1. Nas IAM Apps (`ZPC_IAM_CLIENTES`, `ZPC_IAM_ESTOQUE`, `ZPC_IAM_PEDIDOS`, `ZPC_IAM_REEMBOLSOS` e a IAM App do
   serviço analítico), aba **Authorizations**: confirme que `ZPC_ADMIN`/`ZPC_PEDIDO` estão incluídos e
   **publique** a IAM App.
2. App *Maintain Business Roles* → `ZPC_BR_ADMIN` / `ZPC_BR_COMUM` → **Maintain Restrictions**: na restrição de
   **Read, Value Help** dos objetos, libere a atividade **03**.

**SAP On-Premise**

Na `PFCG`, as roles do tutorial On-Premise já trazem a atividade 03:

| Role         | `ZPC_ADMIN`    | `ZPC_PEDIDO`       | Resultado na leitura                              |
| ------------ | -------------- | ------------------ | ------------------------------------------------- |
| `Z_PC_ADMIN` | 01, 02, 03, 06 | 01, 02, 03, 06, 16 | Vê tudo                                           |
| `Z_PC_COMUM` | 03             | 01, 02, 03         | Vê tudo; altera só pedidos                        |

Para um perfil **somente consulta** (ex.: auditoria), crie `Z_PC_CONSULTA` com `ZPC_ADMIN` 03 e `ZPC_PEDIDO` 03.
Para quem só usa as análises de pedidos, basta `ZPC_PEDIDO` 03 + o serviço `ZUI_PC_ANALITICO_O4`.

Lembre-se de incluir o serviço analítico na `SU24` com os dois objetos (atividade 03) e de gerar o perfil e
rodar a comparação de usuários.

### Passo 4 — Regras de acesso

#### 5.4.1. Clientes (`ZAVBS_PC_CLIENTES`)

```abap
@EndUserText.label: 'Acesso aos clientes'
@MappingRole: true
define role ZC_PC_CLIENTE_APP {
  grant select on ZC_PC_CLIENTE_APP
    where ( ) = aspect pfcg_auth( ZPC_ADMIN, ACTVT = '03' );
}
```

```abap
@EndUserText.label: 'Acesso aos endereços dos clientes'
@MappingRole: true
define role ZC_PC_ENDERECO_APP {
  grant select on ZC_PC_ENDERECO_APP
    where ( ) = aspect pfcg_auth( ZPC_ADMIN, ACTVT = '03' );
}
```

```abap
@EndUserText.label: 'Acesso ao value help de CEP'
@MappingRole: true
define role ZC_PC_CEP_VH {
  grant select on ZC_PC_CEP_VH
    where ( ) = aspect pfcg_auth( ZPC_ADMIN, ACTVT = '01' )
       or ( ) = aspect pfcg_auth( ZPC_ADMIN, ACTVT = '02' );
}
```

```abap
@EndUserText.label: 'Acesso à análise de clientes'
@MappingRole: true
define role ZC_PC_CLIENTE_ANALISE {
  grant select on ZC_PC_CLIENTE_ANALISE
    where ( ) = aspect pfcg_auth( ZPC_ADMIN, ACTVT = '03' );
}
```

> `ZC_PC_CLIENTE_ANALISE` está no pacote `ZAVBS_PC_CLIENTES`; crie a regra no mesmo pacote da view. O mesmo vale
> para as demais análises.

`ZC_PC_CLIENTE_VH` e `ZC_PC_ENDERECO_VH` são consumidas pelo app de pedidos:

```abap
@EndUserText.label: 'Acesso ao value help de clientes'
@MappingRole: true
define role ZC_PC_CLIENTE_VH {
  grant select on ZC_PC_CLIENTE_VH
    where ( ) = aspect pfcg_auth( ZPC_ADMIN,  ACTVT = '03' )
       or ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '01' )
       or ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '02' );
}
```

```abap
@EndUserText.label: 'Acesso ao value help de endereços'
@MappingRole: true
define role ZC_PC_ENDERECO_VH {
  grant select on ZC_PC_ENDERECO_VH
    where ( ) = aspect pfcg_auth( ZPC_ADMIN,  ACTVT = '03' )
       or ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '01' )
       or ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '02' );
}
```

#### 5.4.2. Estoque (`ZAVBS_PC_ESTOQUE`)

```abap
@EndUserText.label: 'Acesso aos itens de estoque'
@MappingRole: true
define role ZC_PC_ITEM_APP {
  grant select on ZC_PC_ITEM_APP
    where ( ) = aspect pfcg_auth( ZPC_ADMIN, ACTVT = '03' );
}
```

```abap
@EndUserText.label: 'Acesso ao value help de itens'
@MappingRole: true
define role ZC_PC_ITEM_VH {
  grant select on ZC_PC_ITEM_VH
    where ( ) = aspect pfcg_auth( ZPC_ADMIN,  ACTVT = '03' )
       or ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '01' )
       or ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '02' );
}
```

```abap
@EndUserText.label: 'Acesso à análise de itens do estoque'
@MappingRole: true
define role ZC_PC_ITEM_ANALISE {
  grant select on ZC_PC_ITEM_ANALISE
    where ( ) = aspect pfcg_auth( ZPC_ADMIN, ACTVT = '03' );
}
```

#### 5.4.3. Pedidos (`ZAVBS_PC_PEDIDOS`)

A raiz e as quatro entidades filhas usam a mesma condição:

```abap
@EndUserText.label: 'Acesso aos pedidos de compra'
@MappingRole: true
define role ZC_PC_PEDIDO_APP {
  grant select on ZC_PC_PEDIDO_APP
    where ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '03' );
}
```

Repita trocando o nome da regra, o `grant select on` e o texto para `ZC_PC_ITEM_PEDIDO_APP`,
`ZC_PC_PAGAMENTO_APP`, `ZC_PC_PED_CLI_SNAP_APP`, `ZC_PC_PED_ITEM_SNAP_APP` e `ZC_PC_PEDIDO_ANALISE`. Exemplo:

```abap
@EndUserText.label: 'Acesso ao pagamento do pedido'
@MappingRole: true
define role ZC_PC_PAGAMENTO_APP {
  grant select on ZC_PC_PAGAMENTO_APP
    where ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '03' );
}
```

> Alternativa para as filhas: herdar a condição da raiz pela associação `_Pedido`, assim uma mudança futura na
> regra do pedido vale para todas:
>
> ```abap
> grant select on ZC_PC_PAGAMENTO_APP
>   where inheriting conditions from entity ZC_PC_PEDIDO_APP
>     replacing { root with _Pedido };
> ```

#### 5.4.4. Reembolsos (`ZAVBS_PC_REEMBOLSOS`)

```abap
@EndUserText.label: 'Acesso aos reembolsos'
@MappingRole: true
define role ZC_PC_REEMBOLSO_APP {
  grant select on ZC_PC_REEMBOLSO_APP
    where ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '03' );
}
```

```abap
@EndUserText.label: 'Acesso à análise de reembolsos'
@MappingRole: true
define role ZC_PC_REEMB_ANALISE {
  grant select on ZC_PC_REEMB_ANALISE
    where ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '03' );
}
```

Total: **17 regras de acesso** e 17 views trocadas para `#CHECK`.

---

## 6. Variações: filtro por linha

As regras acima são "tudo ou nada". A DCL também filtra **registro a registro**, comparando um campo da view
com os valores autorizados ao usuário.

### 6.1. Por UF do cliente (campo de autorização novo)

Exemplo: cada analista só enxerga os clientes da sua região.

1. Crie o campo de autorização **`ZPC_UF`** (BTP: ADT → *Authorization Field*; On-Premise: `SU20`), com o
   elemento de dados da UF.
2. Acrescente `ZPC_UF` ao objeto `ZPC_ADMIN` (`SU21` ou ADT) e mantenha os valores nas roles
   (ex.: `SP`, `RJ`; `*` para o administrador).
3. Ajuste o `AUTHORITY-CHECK` de `ZCL_PC_AUTH` para declarar que a escrita global não depende da UF:

   ```abap
   AUTHORITY-CHECK OBJECT 'ZPC_ADMIN'
     ID 'ACTVT'  FIELD iv_actvt
     ID 'ZPC_UF' DUMMY.
   ```

4. Use o campo na regra:

   ```abap
   define role ZC_PC_CLIENTE_APP {
     grant select on ZC_PC_CLIENTE_APP
       where ( UfPrincipal ) = aspect pfcg_auth( ZPC_ADMIN, ZPC_UF, ACTVT = '03' );
   }
   ```

   e, na análise de clientes, `where ( Uf ) = aspect pfcg_auth( ZPC_ADMIN, ZPC_UF, ACTVT = '03' )`.

> Clientes sem endereço principal têm `UfPrincipal` vazia e só aparecem para quem tem `*` (ou o valor vazio)
> em `ZPC_UF`. Considere isso antes de adotar a regra.
>
> O filtro de leitura não impede a escrita pela UF: para isso seria necessário passar a ter autorização por
> instância (`authorization master ( instance )` com `get_instance_authorizations`), fora do escopo deste
> tutorial.

### 6.2. Pelo usuário que criou o pedido

Exemplo: quem tem `ZPC_PEDIDO` 03 vê todos os pedidos; quem só cria pedidos vê apenas os seus.

```abap
define role ZC_PC_PEDIDO_APP {
  grant select on ZC_PC_PEDIDO_APP
    where ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '03' )
       or ( CreatedBy = aspect user
            and ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '01' ) );
}
```

`aspect user` é o usuário logado; `CreatedBy` é preenchido pelo RAP (`@Semantics.user.createdBy`). Aplique a
mesma ideia às filhas com `inheriting conditions` (seção 5.4.3), para que itens e pagamento sigam o pedido.

---

## 7. Teste do cenário

Crie (ou reutilize) três usuários de teste:

| Usuário       | Autorizações                                    |
| ------------- | ----------------------------------------------- |
| `PC_ADMIN`    | `ZPC_ADMIN` 01/02/03/06, `ZPC_PEDIDO` 01/02/03/06/16 |
| `PC_COMUM`    | `ZPC_ADMIN` 03, `ZPC_PEDIDO` 01/02/03            |
| `PC_SEM_LEIT` | Acesso aos serviços, mas **sem** a atividade 03  |

Roteiro:

1. **`PC_ADMIN`**: todas as apps listam os registros normalmente; análises mostram os mesmos totais de antes.
2. **`PC_COMUM`**: vê clientes, estoque, pedidos e reembolsos; consegue escolher cliente, endereço e item no
   pedido (value helps).
3. **`PC_SEM_LEIT`**:
   - listas, Object Pages e análises voltam **vazias**, sem mensagem de erro;
   - `GET /sap/opu/odata4/.../Pagamento` e `.../ItemPedido` direto pelo entity set também voltam vazios;
   - value helps de status/código continuam funcionando (não têm regra).
4. Com `PC_COMUM`, crie um pedido completo (precheck de estoque, Salvar, pagamento): confirma que as leituras
   internas dos behavior pools (camada R) **não** foram afetadas.
5. No ADT, abra a view com **Data Preview**: o resultado já é filtrado pela DCL do usuário logado.

---

## 8. Diagnóstico de problemas

| Sintoma                                               | Causa provável                                        | Como verificar / corrigir                                  |
| ----------------------------------------------------- | ----------------------------------------------------- | ---------------------------------------------------------- |
| Lista vazia, sem erro                                 | Usuário sem `ACTVT = 03` no objeto da regra           | BTP: *Display Authorization Trace*; On-Prem: `STAUTHTRACE` |
| Tudo vazio para todos os usuários                     | DCL ativada no BTP Trial ou roles sem a atividade 03  | Seção 3; revisar Business Roles / `PFCG`                   |
| Value help de cliente/item vazio ao criar pedido      | Regra do VH sem o `or` de `ZPC_PEDIDO` 01/02          | Comparar com a seção 5.4.1/5.4.2                           |
| Pedido não salva: "cliente inexistente" ou sem estoque | DCL colocada em uma view `ZR_*` usada pelo behavior pool | Remover a regra da camada R ou usar `WITH PRIVILEGED ACCESS` |
| Itens ou pagamento visíveis sem acesso ao pedido      | Entidade filha sem regra própria                      | Criar a regra da filha (seção 5.4.3)                       |
| Aviso "no access control" na view                     | View `#CHECK` sem regra ativa                         | Criar/ativar a regra (Passo 1)                             |
| Regra não tem efeito                                  | Nome errado em `grant select on` ou view `#NOT_ALLOWED` | Conferir o nome e a anotação                             |

No On-Premise, a transação `SACMSEL` mostra a condição gerada pela DCL para um usuário e uma view, e a `SUIM`
lista quem tem a atividade 03 em cada objeto.

---

## 9. Cuidados de segurança e manutenção

- A DCL protege a **leitura**; a escrita continua protegida por `get_global_authorizations`. As duas camadas se
  complementam.
- **Toda nova view exposta** em um serviço precisa de regra: com `#CHECK` o ADT avisa quando ela faltar.
- Não use `#NOT_ALLOWED` nem `WITH PRIVILEGED ACCESS` em leituras feitas **em nome do usuário**.
- Os relatórios e classes que fazem `SELECT` nas views `ZC_*` passam a receber dados filtrados; use a camada R
  quando a regra de negócio precisar de todos os registros.
- Revise as regras quando criar campos de autorização (seção 6) e mantenha os nomes das regras iguais aos das
  views, para facilitar a busca.
- Para desfazer, exclua as regras de acesso e volte as views para `#NOT_REQUIRED`.

---

## 10. Transporte entre ambientes

| Objeto                                   | BTP                                       | On-Premise                         |
| ---------------------------------------- | ----------------------------------------- | ---------------------------------- |
| Regras de acesso (DCL) e views `#CHECK`  | gCTS / abapGit (mesmo pacote das views)   | Ordem Workbench                    |
| Campo `ZPC_UF` e objeto alterado (seção 6) | Junto com os objetos de autorização     | Ordem Workbench (`SU20`/`SU21`)    |
| Atividade 03 nas roles                   | Business Roles (mantidas em cada sistema) | Roles `PFCG` (ordem de transporte) |
| Atribuição de usuários                   | Em cada sistema                           | Em cada sistema (ou CUA/IdM)       |

Transporte as regras **junto com** as views alteradas e só depois de as roles do sistema de destino já terem a
atividade 03 — caso contrário, os usuários ficam sem enxergar os dados até a role ser ajustada.

---

## 11. Checklist final

- [ ] `c_modo_trial = abap_false` e roles/Business Roles configuráveis no sistema
- [ ] 17 regras de acesso criadas e ativas (seção 4)
- [ ] 17 views expostas trocadas para `#CHECK`
- [ ] Camada R (`ZR_*`) e cubos (`ZI_*_CUBE`) sem DCL
- [ ] Value helps do pedido aceitando `ZPC_PEDIDO` 01/02
- [ ] Atividade 03 incluída nas roles (`Z_PC_ADMIN`, `Z_PC_COMUM`) ou Business Roles
- [ ] Serviço analítico com os objetos `ZPC_ADMIN`/`ZPC_PEDIDO` na IAM App ou `SU24`
- [ ] Testes com `PC_ADMIN`, `PC_COMUM` e `PC_SEM_LEIT` realizados
- [ ] Criação completa de pedido testada com `PC_COMUM`
- [ ] Regras e views na mesma ordem de transporte

---

## 12. Resultado

```text
Usuário -> serviço OData -> SELECT na view ZC_*  (#CHECK)
                               |
                               +-- DCL: aspect pfcg_auth( ZPC_ADMIN / ZPC_PEDIDO, ACTVT = '03' )
                               |       -> WHERE acrescentado pelo ABAP: tudo, filtrado ou nada
                               |
Behavior pools -> SELECT na view ZR_*  (sem DCL: regras de negócio enxergam tudo)
```

Com a implementação, cada usuário só lê os dados para os quais tem autorização de exibição, e a escrita
continua controlada por `ZCL_PC_AUTH`.

---

## Referências

- ABAP Keyword Documentation — *ABAP CDS - Access Control* (`DEFINE ROLE`, `GRANT SELECT ON`)
- ABAP Keyword Documentation — *ABAP CDS - PFCG Conditions* (`aspect pfcg_auth`) e *User Conditions*
  (`aspect user`)
- ABAP Keyword Documentation — *ABAP CDS - Inherited Conditions* (`inheriting conditions from entity`)
- ABAP Keyword Documentation — `@AccessControl.authorizationCheck` e `SELECT ... WITH PRIVILEGED ACCESS`
- SAP Help — *Authorization Control* (ABAP RESTful Application Programming Model)
- [Tutorial: Validação de autorização (AUTHORITY-CHECK) no SAP On-Premise](tutorial_autorizacao_btp_para_onpremise.md)
