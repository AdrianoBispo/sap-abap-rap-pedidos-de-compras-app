# Tutorial: Validação de autorização (AUTHORITY-CHECK) do SAP BTP ABAP Environment para SAP On-Premise

## 1. Objetivo

Este tutorial mostra como levar a validação de autorização do projeto **Pedidos de Compras**, desenvolvida no
**SAP BTP ABAP Environment**, para um sistema **SAP S/4HANA On-Premise** (ABAP Platform).

A boa notícia é que **o código de autorização não muda**. O `AUTHORITY-CHECK`, os métodos
`get_global_authorizations` dos behavior pools e as regras de acesso CDS (DCL) funcionam da mesma forma nos
dois ambientes. O que muda é **onde e como** os objetos de autorização são criados e atribuídos aos usuários:

| Etapa                         | SAP BTP ABAP Environment                          | SAP On-Premise                                     |
| ----------------------------- | ------------------------------------------------- | -------------------------------------------------- |
| Objeto de autorização         | ADT (classe `CPAE`)                               | `SU21` (classe própria, ex.: `ZPC`) ou ADT         |
| Campos de autorização         | ADT                                               | `SU20`                                             |
| Vínculo serviço × autorização | IAM App (`.sia6`)                                 | `SU24` (valores propostos)                         |
| Agrupamento para o usuário    | Business Catalog                                  | Role (`PFCG`) + catálogo/espaço do Launchpad       |
| Atribuição ao usuário         | Business Role no app *Maintain Business Users*    | `PFCG` / `SU01`                                    |
| Acesso ao serviço OData       | Automático pela IAM App                           | `S_START` (OData V4) ou `S_SERVICE` (OData V2)     |
| Diagnóstico                   | *Display Authorization Trace*                     | `SU53`, `STAUTHTRACE`, `SUIM`                      |

Resumo do roteiro:

1. desligar o modo trial em `ZIF_PC_CONSTANTS`;
2. criar a classe e os objetos de autorização (`SU21`) com as atividades corretas;
3. publicar os serviços OData (`/IWFND/V4_ADMIN` ou `/IWFND/MAINT_SERVICE`);
4. manter os valores propostos dos serviços (`SU24`);
5. criar as roles `Z_PC_ADMIN` e `Z_PC_COMUM` (`PFCG`) e atribuí-las aos usuários (`SU01`);
6. (recomendado) proteger a leitura com regras de acesso CDS (DCL);
7. testar e diagnosticar com `SU53` e `STAUTHTRACE`.

---

## 2. Arquitetura antes e depois

### Antes: SAP BTP ABAP Environment

```text
Usuário
    -> Business Role (ZPC_BR_ADMIN / ZPC_BR_COMUM)
        -> Business Catalog
            -> IAM App (.sia6) do serviço
                -> Objetos ZPC_ADMIN / ZPC_PEDIDO (classe CPAE)
                    -> ZCL_PC_AUTH (AUTHORITY-CHECK)
                        -> get_global_authorizations (behavior pools)
```

A IAM App libera o serviço OData e carrega as restrições dos objetos de autorização.

### Depois: SAP On-Premise

```text
Usuário (SU01)
    -> Role Z_PC_ADMIN / Z_PC_COMUM (PFCG)
        -> S_START (grupo de serviços OData V4) ou S_SERVICE (OData V2)
        -> ZPC_ADMIN / ZPC_PEDIDO (SU21, valores via SU24)
            -> ZCL_PC_AUTH (AUTHORITY-CHECK)          <- mesmo código
                -> get_global_authorizations          <- mesmo código
        -> Catálogo / espaço do Fiori Launchpad (/UI2/FLPD_CUST)
```

As IAM Apps e os Business Catalogs **não existem** no On-Premise; o papel deles é assumido pela role da `PFCG`.

---

## 3. Pré-requisitos

- SAP S/4HANA On-Premise **2022 ou superior** (ABAP Platform com RAP managed + draft e `strict ( 2 )`);
- objetos ABAP do projeto importados no sistema (abapGit ou transporte);
- usuário de desenvolvimento com acesso às transações `SU21`, `SU20`, `SU24`, `PFCG`, `SU01`, `/IWFND/V4_ADMIN`,
  `/IWFND/MAINT_SERVICE`, `/UI2/FLPD_CUST`, `SU53` e `STAUTHTRACE`;
- SAP Gateway configurado (hub embarcado ou separado) com o alias de sistema `LOCAL`;
- ordem de transporte **Workbench** (objetos de autorização, SU24) e **Customizing** (roles, se a política exigir).

---

## 4. O que já existe no projeto (e continua igual)

### 4.1. Classe central `ZCL_PC_AUTH`

Toda verificação passa por `ZCL_PC_AUTH` (pacote `ZAVBS_PC_COMMON`), que encapsula o `AUTHORITY-CHECK`
dos objetos `ZPC_ADMIN` (clientes e estoque) e `ZPC_PEDIDO` (pedidos e reembolsos):

```abap
CONSTANTS: BEGIN OF c_actvt,
             criar    TYPE c LENGTH 2 VALUE '01',
             alterar  TYPE c LENGTH 2 VALUE '02',
             excluir  TYPE c LENGTH 2 VALUE '06',
             executar TYPE c LENGTH 2 VALUE '16',
           END OF c_actvt.

METHOD verificar_pedido.
  IF zif_pc_constants=>c_modo_trial = abap_true.
    rv_autorizado = abap_true.
    RETURN.
  ENDIF.
  AUTHORITY-CHECK OBJECT 'ZPC_PEDIDO' ID 'ACTVT' FIELD iv_actvt.
  rv_autorizado = xsdbool( sy-subrc = 0 ).
ENDMETHOD.
```

| Método                 | Objeto       | ACTVT | Usado em                                                       |
| ---------------------- | ------------ | ----- | -------------------------------------------------------------- |
| `admin_pode_criar`     | `ZPC_ADMIN`  | 01    | Clientes e Estoque: `%create`, `ImportarPlanilha`              |
| `admin_pode_alterar`   | `ZPC_ADMIN`  | 02    | Clientes e Estoque: `%update`, `Edit`, `DefinirEnderecoPrincipal` |
| `admin_pode_excluir`   | `ZPC_ADMIN`  | 06    | Clientes e Estoque: `%delete`                                  |
| `pedido_pode_criar`    | `ZPC_PEDIDO` | 01    | Pedidos: `%create`, `ImportarPlanilha`                         |
| `pedido_pode_alterar`  | `ZPC_PEDIDO` | 02    | Pedidos: `%update`, `Edit`                                     |
| `pedido_pode_excluir`  | `ZPC_PEDIDO` | 06    | Pedidos: `%delete`                                             |
| `pedido_pode_executar` | `ZPC_PEDIDO` | 16    | Pedidos: `SimularPagamento`, `AprovarPedido`, `CancelarPedido`; Reembolsos: `%create`, `AprovarReembolso`, `RejeitarReembolso` |

### 4.2. Autorização global nos behavior definitions

Os BOs `ZR_PC_PEDIDO`, `ZR_PC_ITEM`, `ZR_PC_CLIENTE` e `ZR_PC_REEMBOLSO` declaram
`authorization master ( global )`. As entidades filhas do pedido usam `authorization dependent by _Pedido` e as
ações internas (`CancelarPorReembolso`, `RetomarPedido`, `ReservarEstoque`, `LiberarReserva`, `BaixarEstoque`)
usam `authorization : none`, pois só são chamadas por EML dentro de uma operação já autorizada.

Exemplo de `ZBP_R_PC_PEDIDO`:

```abap
METHOD get_global_authorizations.
  IF requested_authorizations-%create = if_abap_behv=>mk-on.
    result-%create = COND #( WHEN zcl_pc_auth=>pedido_pode_criar( ) = abap_true
                             THEN if_abap_behv=>auth-allowed
                             ELSE if_abap_behv=>auth-unauthorized ).
  ENDIF.
  ...
  DATA(lv_exec) = COND #( WHEN zcl_pc_auth=>pedido_pode_executar( ) = abap_true
                          THEN if_abap_behv=>auth-allowed
                          ELSE if_abap_behv=>auth-unauthorized ).
  IF requested_authorizations-%action-AprovarPedido = if_abap_behv=>mk-on.
    result-%action-AprovarPedido = lv_exec.
  ENDIF.
ENDMETHOD.
```

> O framework RAP chama esse método antes de cada operação. No Fiori Elements, os botões **Criar**, **Editar**,
> **Excluir** e as ações ficam desabilitados ou retornam erro 403 quando o resultado é `auth-unauthorized`.

---

## 5. Passo a passo no On-Premise

### Passo 1 — Desligar o modo trial

Em `ZIF_PC_CONSTANTS`, o modo trial libera todas as verificações (no BTP Trial não é possível atribuir objetos
de autorização próprios ao usuário). No On-Premise ele **precisa** ser desligado:

```abap
CONSTANTS c_modo_trial TYPE abap_boolean VALUE abap_false.
```

> Enquanto `c_modo_trial = abap_true`, nenhum `AUTHORITY-CHECK` é executado e qualquer usuário com acesso ao
> serviço consegue criar, alterar, excluir e executar ações.

### Passo 2 — Classe e objetos de autorização (`SU21`)

1. Em `SU21`, crie a classe de objetos **`ZPC`** — *Pedidos de Compras* (a classe `CPAE` é do BTP).
2. Crie os objetos dentro da classe `ZPC`:

| Objeto       | Texto                          | Campo   | Atividades permitidas          |
| ------------ | ------------------------------ | ------- | ------------------------------ |
| `ZPC_ADMIN`  | Cadastros (clientes e estoque) | `ACTVT` | 01, 02, 03, 06                 |
| `ZPC_PEDIDO` | Pedidos e reembolsos           | `ACTVT` | 01, 02, 03, 06, **16**         |

3. Em cada objeto, use **Atividades permitidas** para restringir o campo `ACTVT` às atividades da tabela.

> **Atenção:** o arquivo `ZPC_PEDIDO.susob.xml` do repositório só tem as atividades 01, 02, 03 e 06. Sem a
> atividade **16 (Executar)**, nenhum usuário consegue `SimularPagamento`, `AprovarPedido`, `CancelarPedido`,
> criar reembolso, `AprovarReembolso` ou `RejeitarReembolso` assim que o modo trial for desligado. Inclua a 16
> no On-Premise (e corrija também o objeto no BTP).

Se no futuro for necessário restringir por dados (ex.: por UF do endereço ou por centro), crie o campo em
`SU20` (ex.: `ZPC_UF`, elemento de dados de UF) e acrescente-o ao objeto em `SU21`.

### Passo 3 — Publicar os serviços OData

| Serviço do projeto           | Versão  | Como publicar                                                  |
| ---------------------------- | ------- | -------------------------------------------------------------- |
| `ZUI_PC_PEDIDOS_COMPRAS_O4`  | V4      | ADT (*Publish* no service binding) ou `/IWFND/V4_ADMIN`        |
| `ZUI_PC_CLIENTES_O4`         | V4      | idem                                                           |
| `ZUI_PC_ESTOQUE_O4`          | V4      | idem                                                           |
| `ZUI_PC_REEMBOLSOS_O4`       | V4      | idem                                                           |
| `ZUI_PC_ANALITICO_O4`        | V4      | idem (apps de análise)                                         |
| `ZUI_PC_ANALITICO_O2`        | V2      | `/IWFND/MAINT_SERVICE` (binding V2 do repositório, opcional)   |

No OData V4, a publicação cria um **grupo de serviços** (ex.: `ZUI_PC_PEDIDOS_COMPRAS_O4`), que é o valor
verificado pelo objeto `S_START`. No OData V2, o serviço é registrado em `/IWFND/MAINT_SERVICE` e verificado
pelo objeto `S_SERVICE`.

### Passo 4 — Valores propostos (`SU24`)

Em `SU24`, vincule cada serviço aos objetos de autorização que ele usa. Assim a `PFCG` já traz os objetos
certos ao adicionar o serviço ao menu da role.

1. Tipo de aplicação: **Serviço externo** → tipo `IWSG` (V2) ou **grupo de serviços OData V4** (`G4BA`).
2. Para cada serviço, adicione os objetos e os valores propostos:

| Serviço                          | Objeto       | Valores propostos de `ACTVT` |
| -------------------------------- | ------------ | ---------------------------- |
| `ZUI_PC_CLIENTES_O4`             | `ZPC_ADMIN`  | 01, 02, 03, 06               |
| `ZUI_PC_ESTOQUE_O4`              | `ZPC_ADMIN`  | 01, 02, 03, 06               |
| `ZUI_PC_PEDIDOS_COMPRAS_O4`      | `ZPC_PEDIDO` | 01, 02, 03, 06, 16           |
| `ZUI_PC_REEMBOLSOS_O4`           | `ZPC_PEDIDO` | 03, 16                       |
| `ZUI_PC_ANALITICO_O4`            | `ZPC_PEDIDO`, `ZPC_ADMIN` | 03 (somente com DCL, ver passo 7) |

3. Grave os dados de `SU24` em uma ordem Workbench.

### Passo 5 — Roles (`PFCG`)

Crie duas roles simples, equivalentes às Business Roles do BTP (`ZPC_BR_ADMIN` / `ZPC_BR_COMUM`):

| Role         | Perfil de usuário                         | `ZPC_ADMIN` | `ZPC_PEDIDO`          |
| ------------ | ----------------------------------------- | ----------- | --------------------- |
| `Z_PC_ADMIN` | Administrador: cadastros, pedidos e gestão de reembolsos | 01, 02, 03, 06 | 01, 02, 03, 06, 16 |
| `Z_PC_COMUM` | Usuário comum: consulta cadastros e opera pedidos        | 03             | 01, 02, 03         |

Para cada role:

1. **Menu** → *Inserir nó* → *Autorização para serviço* e adicione os serviços OData:
   - OData V4: tipo **`G4BA`** (grupo de serviços) → gera `S_START` com `AUTHPGMID = R3TR`, `AUTHOBJTYP = G4BA`
     e `AUTHOBJNAM = <grupo de serviços>`;
   - OData V2: tipo **`IWSG`** → gera `S_SERVICE`.
2. (Opcional) inclua no menu o catálogo do Fiori Launchpad criado em `/UI2/FLPD_CUST` com os tiles das apps
   (ou o espaço/página, no S/4HANA 2020+).
3. **Autorizações** → *Alterar dados de autorização*: os objetos `ZPC_ADMIN`/`ZPC_PEDIDO` vêm da `SU24`;
   ajuste as atividades conforme a tabela acima.
4. **Gerar** o perfil.
5. Grave a role em uma ordem de transporte.

> O usuário comum não recebe a atividade 16: ele cria e altera pedidos, mas não simula pagamento, não aprova
> e não cancela. Ajuste a matriz conforme o processo da empresa.

### Passo 6 — Atribuir aos usuários (`SU01` / `PFCG`)

1. Em `SU01` (aba **Funções**) ou na aba **Usuário** da `PFCG`, atribua `Z_PC_ADMIN` ou `Z_PC_COMUM`.
2. Na `PFCG`, execute a **Comparação de usuários** para gravar o perfil gerado no usuário.
3. Faça logoff/logon (ou limpe o cache do Launchpad) para que as novas autorizações valham.

### Passo 7 — (Recomendado) Proteger a leitura com DCL

Hoje todas as CDS do projeto usam `@AccessControl.authorizationCheck: #NOT_REQUIRED`: quem tem acesso ao
serviço consegue **ler** todos os dados. Para exigir a atividade 03 (Exibir), troque a anotação para
`#CHECK` nas views de consumo e crie uma regra de acesso (*Access Control*) para cada uma:

```abap
@EndUserText.label: 'Acesso aos pedidos de compra'
@MappingRole: true
define role ZC_PC_PEDIDO {
  grant select on ZC_PC_PEDIDO
    where ( ) = aspect pfcg_auth( ZPC_PEDIDO, ACTVT = '03' );
}
```

Repita para clientes e estoque com `ZPC_ADMIN` e para as views analíticas `ZC_PC_*_ANALISE`. Se for criado um
campo de dados (ex.: `ZPC_UF`), a regra pode filtrar linhas:

```abap
grant select on ZC_PC_CLIENTE
  where ( Uf ) = aspect pfcg_auth( ZPC_ADMIN, ZPC_UF, ACTVT = '03' );
```

> A DCL funciona igual no BTP e no On-Premise. Lembre-se de propagar `#CHECK` também para as views de
> interface/projeção usadas diretamente em value helps.

### Passo 8 — Testes unitários de autorização

Para testar `get_global_authorizations` sem depender das roles do usuário que executa o teste, use o
framework de dublês de autorização `CL_AUNIT_AUTHORITY_CHECK`:

```abap
DATA(lo_ctrl) = cl_aunit_authority_check=>get_controller( ).
DATA(lo_role) = cl_aunit_authority_check=>create_auth_object_set(
  VALUE #( ( object = 'ZPC_PEDIDO'
             authorizations = VALUE #( ( VALUE #( ( fieldname = 'ACTVT' fieldvalues = VALUE #( ( lower_value = '03' ) ) ) ) ) ) ) ) ).
lo_ctrl->restrict_authorizations_to( lo_role ).

" Executa a operação por EML e verifica que %create foi negado
```

> Lembre-se de que os testes só são significativos com `c_modo_trial = abap_false`.

---

## 6. Ajustes no repositório para a migração

| Item                                      | Ação no On-Premise                                                                 |
| ----------------------------------------- | ---------------------------------------------------------------------------------- |
| `ZIF_PC_CONSTANTS=>c_modo_trial`          | Alterar para `abap_false`                                                          |
| `ZPC_PEDIDO.susob.xml`                    | Incluir a atividade 16 (Executar)                                                  |
| `*.susob.xml` (classe `CPAE`)             | Recriar os objetos na classe própria `ZPC` via `SU21`                              |
| `*.sia6.xml` (IAM Apps)                   | **Não transportar**: o tipo não existe no On-Premise; substituído por `SU24` + `PFCG` |
| Business Catalogs / Business Roles        | Substituídos pelas roles `Z_PC_ADMIN` e `Z_PC_COMUM`                               |
| `@AccessControl.authorizationCheck`       | Avaliar `#CHECK` + DCL (passo 7)                                                   |
| Apps SAPUI5 (BSP)                         | Sem alteração de autorização; tiles via catálogo do Launchpad na role              |

---

## 7. Teste do cenário

1. Crie dois usuários de teste: `PC_ADMIN` (role `Z_PC_ADMIN`) e `PC_COMUM` (role `Z_PC_COMUM`).
2. Com `PC_COMUM`:
   - **Gestão de Clientes**: o botão **Criar** deve estar desabilitado e **Editar**/**Excluir** indisponíveis;
   - **Pedidos de Compras**: deve criar e editar pedidos, mas **Efetuar Pagamento**, **Aprovar** e **Cancelar**
     devem ser negados;
   - **Gestão de Reembolsos**: **Aprovar**/**Rejeitar** devem ser negados.
3. Com `PC_ADMIN`, todas as operações devem funcionar.
4. Remova a role de `PC_COMUM` e confirme que os serviços retornam **403 Forbidden** (falta `S_START`).

---

## 8. Diagnóstico de problemas

| Sintoma                                              | Causa provável                                     | Como verificar / corrigir                                 |
| ---------------------------------------------------- | -------------------------------------------------- | --------------------------------------------------------- |
| App não abre; serviço retorna **403**                | Falta `S_START` (V4) ou `S_SERVICE` (V2) na role   | `SU53` logo após o erro; incluir o serviço no menu da `PFCG` |
| Botões **Criar/Editar/Excluir** desabilitados        | `AUTHORITY-CHECK` em `ZPC_ADMIN`/`ZPC_PEDIDO` falhou | `STAUTHTRACE` filtrando o usuário e o objeto             |
| Ações do pedido sempre negadas, até para o admin     | Atividade 16 não existe no objeto `ZPC_PEDIDO`     | `SU21` → *Atividades permitidas*                          |
| Todos conseguem tudo                                 | `c_modo_trial` ainda `abap_true`                   | Conferir `ZIF_PC_CONSTANTS`                               |
| Lista vazia sem mensagem de erro                     | DCL ativa e usuário sem atividade 03               | `STAUTHTRACE`; `SACMSEL` para simular a regra de acesso  |
| Role alterada, mas o usuário continua sem acesso     | Perfil não gerado ou sem comparação de usuários    | `PFCG` → gerar perfil → comparação de usuários            |
| Tile não aparece no Launchpad                        | Catálogo/espaço não está na role                   | `/UI2/FLPD_CUST` e menu da `PFCG`; limpar cache (`/UI2/INVALIDATE_GLOBAL_CACHES`) |

Para relatórios de quem tem acesso a cada objeto, use `SUIM` → *Usuários por critérios complexos* →
*por valores de autorização*.

---

## 9. Cuidados de segurança e manutenção

- **Nunca** transporte para produção com `c_modo_trial = abap_true`.
- Mantenha o `AUTHORITY-CHECK` concentrado em `ZCL_PC_AUTH`; os behavior pools só consultam a classe.
- As ações com `authorization : none` devem continuar sendo chamadas **apenas** por EML interno
  (não exponha essas ações na projeção do serviço).
- A action `ImportarPlanilha` revalida `pedido_pode_criar`/`admin_pode_criar` dentro da implementação:
  mantenha essa dupla checagem, pois ela grava registros em massa.
- Revise periodicamente as roles com `SUIM` e use roles derivadas se houver restrição por organização (ex.: UF).
- Prefira atribuir roles compostas por perfil de negócio em vez de atribuir objetos diretamente.

---

## 10. Transporte entre ambientes

| Objeto                                  | Tipo de ordem | Observação                                         |
| --------------------------------------- | ------------- | -------------------------------------------------- |
| Classe de objetos `ZPC`, objetos `ZPC_*`| Workbench     | `SU21`                                             |
| Campos de autorização (`SU20`)          | Workbench     | Somente se criados                                 |
| Valores propostos (`SU24`)              | Workbench     | Vinculados aos serviços                            |
| Publicação dos serviços OData           | Customizing   | `/IWFND/V4_ADMIN` ou `/IWFND/MAINT_SERVICE`; em alguns cenários a publicação é refeita em cada sistema |
| Roles `Z_PC_ADMIN` / `Z_PC_COMUM`       | Workbench ou Customizing | Gerar o perfil novamente no sistema de destino |
| Catálogos/espaços do Launchpad          | Customizing   | `/UI2/FLPD_CUST`                                   |
| Atribuição de usuários                  | —             | **Não** é transportada; feita em cada sistema (ou via CUA/IdM) |

---

## 11. Checklist final

- [ ] `c_modo_trial` alterado para `abap_false`
- [ ] Classe `ZPC` e objetos `ZPC_ADMIN` e `ZPC_PEDIDO` criados em `SU21`
- [ ] Atividade 16 incluída em `ZPC_PEDIDO`
- [ ] Serviços OData publicados
- [ ] Valores propostos mantidos em `SU24`
- [ ] Roles `Z_PC_ADMIN` e `Z_PC_COMUM` criadas, com `S_START`/`S_SERVICE`, e perfis gerados
- [ ] Catálogo/espaço do Launchpad incluído nas roles
- [ ] Usuários atribuídos e comparação de usuários executada
- [ ] (Opcional) DCL criada e CDS de consumo com `#CHECK`
- [ ] Testes com os usuários `PC_ADMIN` e `PC_COMUM` realizados
- [ ] `SU53`/`STAUTHTRACE` sem negações inesperadas
- [ ] Objetos gravados nas ordens de transporte

---

## 12. Resultado da migração

Ao final, o projeto mantém **o mesmo código de autorização** do SAP BTP ABAP Environment, e a configuração de
acesso passa a ser feita com as ferramentas clássicas do On-Premise:

```text
SU21 (objetos) -> SU24 (valores propostos) -> PFCG (roles) -> SU01 (usuários)
                                                   |
                         S_START / S_SERVICE  +  ZPC_ADMIN / ZPC_PEDIDO
                                                   |
                         ZCL_PC_AUTH -> get_global_authorizations (RAP)
```

O administrador controla quem cria, altera, exclui e executa ações em cada app, e a leitura pode ser
protegida pelas regras de acesso CDS.

---

## Referências

- SAP Help — *Authorization Control* (ABAP RESTful Application Programming Model)
- SAP Help — *Implementing Global Authorization* (`get_global_authorizations`)
- SAP Help — *ABAP CDS Access Control* (`define role`, `pfcg_auth`)
- SAP Help — *Authorization Objects* (`SU21`) e *Maintaining Authorization Default Values* (`SU24`)
- SAP Help — *Role Administration* (`PFCG`)
- SAP Help — *SAP Gateway Foundation: OData V4 Service Group Authorization* (`S_START`, `/IWFND/V4_ADMIN`)
- SAP Help — *System Trace for Authorizations* (`STAUTHTRACE`)
- ABAP Keyword Documentation — `AUTHORITY-CHECK` e `CL_AUNIT_AUTHORITY_CHECK`
- [Tutorial: Migração da consulta ViaCEP do SAP BTP ABAP Environment para SAP On-Premise](tutorial_migracao_viacep_btp_para_onpremise.md)
