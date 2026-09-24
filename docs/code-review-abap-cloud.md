# Code Review — Pedidos de Compras (SAP RAP / ABAP Cloud)

Revisão do código gerado em `Pedidos_de_Compras_RAP_codigo.zip` (30 objetos ABAP/CDS/BDEF, 4 pacotes).
Data: 20/09/2026 · Escopo: leitura estática (nenhuma alteração aplicada).

## 1. Premissas de compatibilidade

| Item | Premissa |
|---|---|
| Destino | SAP BTP ABAP Environment (Trial), language version **ABAP for Cloud Development** |
| Release mínimo assumido | 7.54+ (BDEF `strict ( 2 )`, `with draft`, `Activate optimized`, side effects) |
| Verificação executada | abaplint 2.120 (perfil *Cloud*): parser ABAP/CDS + `check_syntax` → 0 erros |
| Não executado | Ativação no ADT, ATC, ABAP Unit, teste de carga/concorrência |
| Conclusão | O código é **majoritariamente** compatível com ABAP Cloud; há **1 API não liberada** que impede a ativação e 4 pontos que devem ser corrigidos antes de uso produtivo |

Legenda de severidade: **B** = bloqueador (impede ativação ou corrompe dados) · **R** = risco de migração/execução · **M** = melhoria opcional.

---

## 2. Bloqueadores (must-fix)

### B1 — `/ui2/cl_json` não é uma API liberada (C1)
**Objeto:** `ZCL_PC_VIACEP` — `zcl_pc_viacep.clas.abap:119`

```abap
/ui2/cl_json=>deserialize( EXPORTING json = lv_json
                           CHANGING  data = rs_resultado-endereco ).
```

**Evidência/impacto:** o pacote `/UI2/` não existe no BTP ABAP Environment e, em S/4HANA com ABAP Cloud,
a classe não tem contrato de liberação C1. O ADT rejeita a ativação com *"não liberado para uso em ABAP
for Cloud Development"*. Este é o único uso de API não liberada em todo o projeto.

**Remediação (preferencial — XCO, liberada):**

```abap
TRY.
    xco_cp_json=>data->from_string( lv_json )->write_to( REF #( rs_resultado-endereco ) ).
  CATCH cx_xco_runtime_exception.
    rs_resultado-indisponivel = abap_true.
    RETURN.
ENDTRY.
```

**Remediação alternativa (sem dependência de API, 100% garantida):** como o JSON do ViaCEP é plano,
extrair campo a campo:

```abap
METHODS extrair_campo
  IMPORTING iv_json TYPE string
            iv_campo TYPE string
  RETURNING VALUE(rv_valor) TYPE string.

METHOD extrair_campo.
  FIND PCRE |"{ iv_campo }"\\s*:\\s*"([^"]*)"| IN iv_json SUBMATCHES rv_valor.
ENDMETHOD.
```

---

### B2 — Chamada HTTP dentro da fase de save (validation)
**Objeto:** `ZBP_R_PC_CLIENTE`, método `ValidarCep` — `zbp_r_pc_cliente.clas.locals_imp.abap:683`

**Evidência/impacto:** `ValidarCep` é uma `validation ... on save`, executada na *check-before-save phase*,
com os locks do BO já adquiridos. Uma chamada remota nesse ponto mantém a LUW e os enqueues abertos pelo
tempo de resposta do ViaCEP (ou pelo timeout, se o serviço estiver fora do ar). É exatamente o padrão que
o guia de RAP desaconselha: a fase de save deve ser curta, determinística e sem I/O remoto.

**Remediação:** manter a chamada apenas na determination `PreencherEnderecoViaCep` (fase de interação,
`zbp_r_pc_cliente.clas.locals_imp.abap:559`), que já grava `Cidade`, `Uf`, `Estado` e `CepGeral`. A validation
passa a checar apenas o estado persistido:

```abap
" ValidarCep - sem I/O remoto
IF ls_end-Cidade IS INITIAL OR ls_end-Uf IS INITIAL.
  lo_msg = NEW #( textid = zcx_pc_msg=>cep_invalido ).   " determination não conseguiu resolver
ELSEIF ls_end-CepGeral = abap_true AND ls_end-Logradouro IS INITIAL.
  lo_msg = NEW #( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Logradouro' ).
ENDIF.
```

Para distinguir "CEP inválido" de "ViaCEP indisponível", a determination deve reportar a mensagem
`CEP_INDISPONIVEL` (determinations podem preencher `reported`) e deixar os campos vazios.

---

### B3 — `FAILED`/`REPORTED` não avaliados em chamadas EML
**Objetos:** 22 ocorrências de `MODIFY ENTITIES` sem cláusula `FAILED`/`REPORTED`.
Caso mais grave: a **compensação de reserva** em `ZBP_R_PC_PEDIDO`, `movimentar_estoque`
— `zbp_r_pc_pedido.clas.locals_imp.abap:966`

```abap
MODIFY ENTITIES OF zr_pc_item
  ENTITY Item
    EXECUTE LiberarReserva
    FROM VALUE #( FOR r IN lt_reservados ( ... ) ).   " falha silenciosa
```

**Impacto:** se a liberação compensatória falhar, o estoque fica reservado indefinidamente sem nenhum
sinal ao chamador — inconsistência de dados silenciosa. O mesmo vale para `criar_snapshots`
(`:1041`, captura `REPORTED` mas não `FAILED`) e para as determinations que gravam em LOCAL MODE.

**Remediação:** capturar sempre e propagar; em LOCAL MODE, no mínimo, propagar mensagens para `reported`:

```abap
MODIFY ENTITIES OF zr_pc_item
  ENTITY Item EXECUTE LiberarReserva FROM ...
  FAILED DATA(ls_failed_comp)
  REPORTED DATA(ls_reported_comp).

IF ls_failed_comp-item IS NOT INITIAL.
  APPEND VALUE #( %tky = is_pedido-%tky
                  %msg = NEW zcx_pc_msg( textid = zcx_pc_msg=>item_estoque_concorrente
                                         attr1  = lv_sku ) ) TO cs_reported-pedido.
ENDIF.
```

---

### B4 — Unicidade de CPF e SKU sem índice único no banco
**Objetos:** `ZTA_PC_CLIENTE` (campo `cpf`), `ZTA_PC_ITEM` (campo `sku`).
Validações em `zbp_r_pc_cliente.clas.locals_imp.abap:227` e `zbp_r_pc_item.clas.locals_imp.abap:620`.

**Impacto:** a unicidade hoje é garantida apenas por `SELECT SINGLE` dentro da validation. Duas ativações
de draft simultâneas com o mesmo CPF passam nas duas validações (não há lock sobre o valor) e ambas
gravam — duplicidade em produção. É a mesma classe de problema que o documento trata para estoque,
mas sem a proteção do lock.

**Remediação:** criar índice secundário **único** no ADT para os dois campos
(`ZTA_PC_CLIENTE~CPF`, `ZTA_PC_ITEM~SKU`), mantendo a validation para a mensagem amigável e tratando
o `DUPLICATE_KEY` como erro técnico. O índice é o que realmente garante a regra.

---

### B5 — Bypass de autorização embarcado no código
**Objeto:** `ZIF_PC_CONSTANTS=>c_modo_trial` + `ZCL_PC_AUTH` — `zcl_pc_auth.clas.abap:33,46`

```abap
IF zif_pc_constants=>c_modo_trial = abap_true.
  rv_autorizado = abap_true.
  RETURN.
ENDIF.
```

**Impacto:** o valor default entregue é `abap_true`, ou seja, **todas as verificações de perfil estão
desligadas**. Se o pacote for transportado para um sistema real sem alterar a constante, qualquer usuário
com acesso ao serviço vira administrador. Além disso, as verificações usam apenas `ACTVT '02'` (alterar)
e `'16'` (executar) — criar (`01`) e excluir (`06`) não são distinguidos.

**Remediação:** (a) inverter o default para `abap_false` e documentar como habilitar no trial; melhor ainda,
usar uma *feature toggle* em tabela de customizing em vez de constante; (b) checar a atividade correta por
operação:

```abap
METHODS pode_criar   RETURNING VALUE(rv) TYPE abap_boolean.  " ACTVT 01
METHODS pode_alterar RETURNING VALUE(rv) TYPE abap_boolean.  " ACTVT 02
METHODS pode_excluir RETURNING VALUE(rv) TYPE abap_boolean.  " ACTVT 06
```

e usar cada uma no `get_global_authorizations` correspondente (`%create`, `%update`, `%delete`).

---

## 3. Riscos de migração e execução

### R1 — Leitura direta de tabelas draft de outro BO
`zbp_r_pc_cliente.clas.locals_imp.abap:135` (`zd_pc_pedido`), `zbp_r_pc_item.clas.locals_imp.abap:173,202`
(`zd_pc_item_ped`).
Tabelas draft são artefatos internos do framework (estrutura, `%admin`, ciclo de vida e limpeza são
propriedade do RAP). Ler diretamente acopla o código a um contrato não público e ainda faz full scan
(não há índice em `clienteuuid`/`itemuuid`).
**Remediação:** restringir a checagem aos dados ativos, ou expor uma API de consulta no BO Pedido
(`ZCL_PC_PEDIDO_API=>possui_pedido( )`) que use EML/CDS; se a checagem de drafts for realmente necessária,
documentar a dependência e criar índice nas tabelas draft.

### R2 — Pré-validação lê o banco, não o buffer transacional
`zbp_r_pc_pedido.clas.locals_imp.abap:474` (`SELECT ... FROM zr_pc_item`) em `ConfirmarPedido` e
`:727` em `AprovarPedido`.
Num cenário de ação em massa (vários pedidos na mesma LUW) o `SELECT` não enxerga as reservas já feitas
no buffer do BO Item, então a mensagem de "estoque insuficiente" pode não aparecer na pré-validação.
A consistência final está garantida (a action interna do BO Item relê via `READ ENTITIES` sob lock), mas a
mensagem ao usuário pode ser menos precisa.
**Remediação:** trocar a pré-validação por `READ ENTITIES OF zr_pc_item ENTITY Item FIELDS ( ... )`, que
respeita o buffer transacional.

### R3 — Dependência cíclica entre pacotes
`ZPK_PC_CLIENTES` e `ZPK_PC_ESTOQUE` leem tabelas/CDS de `ZPK_PC_PEDIDOS`, que por sua vez depende dos dois.
Ciclos dificultam transporte, *package check* do ATC e reuso.
**Remediação:** publicar a checagem "existe pedido para este cliente/item?" como uma API em
`ZPK_PC_COMMON` (interface + implementação injetada) ou no próprio pacote de Pedidos, e consumir a
interface nos outros dois BOs.

### R4 — Cliente HTTP não é fechado em caminho de erro
`zcl_pc_viacep.clas.abap:96-104` — `lo_cliente->close( )` só é executado no fluxo de sucesso; se
`execute( )` levantar exceção, a conexão fica aberta até o fim da sessão.
**Remediação:** `TRY ... CLEANUP` ou fechar no `CATCH`.

### R5 — Código sem pontos de injeção (não testável)
`ZCL_PC_VIACEP`, `ZCL_PC_AUTH`, `ZCL_PC_NUMERACAO` e `ZCL_PC_PAGAMENTO_SIM` são chamadas estáticas
dentro dos behavior pools. Não há como substituir o ViaCEP nem o gerador de números em ABAP Unit.
**Remediação:** extrair interfaces (`ZIF_PC_VIACEP`, `ZIF_PC_AUTH`, `ZIF_PC_NUMERACAO`) com um
*factory/injector* simples:

```abap
CLASS zcl_pc_injector DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS viacep RETURNING VALUE(ri) TYPE REF TO zif_pc_viacep.
    CLASS-METHODS injetar_viacep IMPORTING ii_double TYPE REF TO zif_pc_viacep.  " só para testes
ENDCLASS.
```

### R6 — `CATCH cx_root`
`zcl_pc_viacep.clas.abap:121` e `zcl_pc_setup.clas.abap:72`.
Captura genérica engole erros de programação (`cx_sy_*`) e dificulta o diagnóstico.
**Remediação:** capturar as exceções específicas (`cx_xco_runtime_exception`, `cx_number_ranges`,
`cx_nr_object_not_found`).

### R7 — Cache estático sem limite em `ZCL_PC_VIACEP`
`gt_cache` cresce durante toda a sessão e pode servir dados antigos numa sessão longa.
**Remediação:** limitar o tamanho (ex.: 100 entradas, descarte FIFO) ou restringir o cache à LUW.

### R8 — Carga de dados de demonstração grava direto nas tabelas
`ZCL_PC_SETUP` (`INSERT zta_pc_cliente`, `zta_pc_endereco`, `zta_pc_item`) ignora determinations e validations
do BO; os dados nascem sem passar pelas regras. Há também `DELETE FROM zta_pc_codelist` sem `WHERE` e
`COMMIT WORK` sem avaliação de `sy-subrc`.
**Remediação:** usar EML (`MODIFY ENTITIES ... COMMIT ENTITIES RESPONSE OF ...`) para os dados de
demonstração e avaliar o response; manter o `INSERT` direto apenas para a tabela de CodeList.
Lembrar que `if_oo_adt_classrun` é ferramenta de desenvolvimento — não deve existir em produção.

### R9 — Desempenho de leituras em loop
`READ TABLE ... WITH KEY` sobre tabelas standard dentro de loops (`ConfirmarPedido`, `AprovarPedido`,
`criar_snapshots`, `CalcularValorItem`) é O(n²).
**Remediação:** declarar as tabelas auxiliares como `SORTED`/`HASHED` com a chave usada, ou usar
`line_exists( )`/tabelas com chave secundária.

### R10 — Ausência de índices secundários nos acessos mais frequentes
`zta_pc_item_ped~item_uuid` (usado em `itens_em_pedidos`), `zta_pc_pedido~cliente_uuid`,
`zta_pc_endereco~cliente_uuid`. Sem índice, cada feature control da lista faz full scan.

---

## 4. Melhorias opcionais (modernização / Clean ABAP)

| # | Item | Objeto |
|---|---|---|
| M1 | Trocar `ALL FIELDS` por `FIELDS ( ... )` nas leituras EML das actions (15 ocorrências) — menos dados no buffer | `zbp_r_pc_pedido`, `zbp_r_pc_item` |
| M2 | `CHECK` no meio de método sai silenciosamente; preferir `IF ... RETURN` explícito (26 ocorrências) | os 3 behavior pools |
| M3 | Usar `ENUM` (7.51+) para `c_movimento`/`c_status_*` em vez de constantes `CHAR` | `ZIF_PC_CONSTANTS`, `lhc_item` |
| M4 | Usar `utclong` + `utclong_current( )` no lugar de `timestampl` + `GET TIME STAMP FIELD` | tabelas de pedido/pagamento |
| M5 | Declarar variáveis no início do método (hoje há `DATA` dentro de `LOOP`) | `ConfirmarPedido`, `movimentar` |
| M6 | Notação húngara (`lv_`, `ls_`, `lt_`) contraria o Clean ABAP; manter apenas se for padrão do time | todo o projeto |
| M7 | `%is_draft = if_abap_behv=>mk-off` explícito nas chaves EML cross-BO (hoje implícito pelo valor inicial) | `movimentar_estoque` |
| M8 | Extrair textos fixos de `ZCL_PC_PAGAMENTO_SIM` (motivos de erro) para a message class, permitindo tradução | `zcl_pc_pagamento_sim.clas.abap:78-96` |
| M9 | ABAP Doc (`"!`) nos métodos das classes locais dos behavior pools | behavior pools |
| M10 | `@AccessControl.authorizationCheck: #NOT_REQUIRED` em todas as CDS gera *finding* de ATC; se mantido, justificar com pseudo-comentário `"#EC CI_...` ou criar DCL | 22 CDS |

---

## 5. Testes recomendados

1. **ABAP Unit — lógica pura** (sem dependências, começa hoje):
   `ZCL_PC_UTIL` (CPF válido/inválido/repetido, e-mail, magic bytes de JPEG/PNG, faixas de status de estoque)
   e `ZCL_PC_PAGAMENTO_SIM` (bandeira por prefixo, CVV 000, validade expirada, número fora de 13–19 dígitos).
2. **ABAP Unit — BO com test double do RAP**: `cl_abap_behv_test_environment=>create( )` para testar
   `ConfirmarPedido`, `AprovarPedido` e `CancelarPedido` sem banco, incluindo o caso de estoque insuficiente
   e o de falha parcial (compensação).
3. **CDS/SQL**: `cl_osql_test_environment` para `ZC_PC_CLIENTE_VALUEHELP`, `ZC_PC_ITEM_VALUEHELP` e
   para as consultas de "possui pedido vinculado".
4. **Concorrência (manual, no sistema)**: duas sessões confirmando pedidos do mesmo item; uma sessão com o
   item em draft na app de Estoque enquanto a outra confirma — validar `ITEM_ESTOQUE_CONCORRENTE`.
5. **ATC**: executar com a variante de nuvem do sistema
   (`SAP_CLOUD_PLATFORM_ATC_DEFAULT` no BTP; `ABAP_CLOUD_READINESS` em S/4 on-prem),
   incluindo as checks *Usage of Released APIs*, *RAP Behavior Definition* e *CDS Authorization*.
   Rodar também o *Package Check* — é ele que deve apontar o ciclo descrito em R3.

## 6. Verificações que só o sistema pode responder

- Ativação de todos os objetos no ADT (ordem do README) e existência dos objetos manuais
  (`ZPC_MSG`, `ZPC_NR` + domínio, objetos de autorização).
- Se a instalação do BTP libera `CL_NUMBERRANGE_INTERVALS` e `IF_SADL_EXIT_CALC_ELEMENT_READ`
  (ambos usados em tutoriais oficiais, mas a lista de liberação varia por release).
- Alcance de `https://viacep.com.br` a partir do ambiente (certificado na trust store, egress permitido).
- Comportamento real dos *side effects* declarados no BDEF na app Fiori Elements gerada.
- Se o trial permite manter Business Roles — é isso que decide o destino do item B5.

---

## 7. Resumo

| Severidade | Quantidade | Ação |
|---|---|---|
| Bloqueador (B1–B5) | 5 | Corrigir antes da ativação (B1) e antes de qualquer uso produtivo (B2–B5) |
| Risco (R1–R10) | 10 | Corrigir durante a estabilização |
| Melhoria (M1–M10) | 10 | Backlog técnico |

O desenho RAP em si está aderente às boas práticas: separação root/child, feature control para status,
autorização global para perfil, EML entre BOs com lock e releitura, snapshots imutáveis e nenhum dado
sensível de cartão persistido. Os bloqueadores são pontuais e localizados — B1 em uma linha, B2 em um
método, B3 em um padrão repetido de chamadas EML, B4 em dois índices de DDIC e B5 em uma constante.

---

## 8. Status das correções (v1.1 do código — 20/09/2026)

| ID | Status | O que mudou |
|---|---|---|
| **B1** | Corrigido | `ZCL_PC_VIACEP` não usa mais `/ui2/cl_json`. O JSON plano do ViaCEP é lido por `FIND PCRE ... SUBMATCHES` em `extrair_campo( )`; o cabeçalho da classe documenta a alternativa `xco_cp_json` para quem preferir a API XCO. |
| **B2** | Corrigido | Novo campo `CepStatus` (`V` validado / `I` inválido / `X` indisponível) em `ZTA_PC_ENDERECO`. A determination `PreencherEnderecoViaCep` (fase de interação) é a **única** que chama o ViaCEP e grava o status; `ValidarCep` passou a ser puramente local. Nenhuma chamada remota na fase de save. |
| **B3** | Corrigido | Todas as chamadas EML avaliam retorno. Novo helper `propagar( )` em `lhc_pedido`; compensação de reserva e criação de snapshots propagam erro (snapshot com falha marca o pedido como `failed`); determinations repassam mensagens com `APPEND CORRESPONDING`. Verificação automatizada: nenhuma `MODIFY ENTITIES` sem `FAILED`/`REPORTED`. |
| **B4** | Documentado | Índices adicionados à seção 2.9 do README (únicos em `ZTA_PC_CLIENTE~CPF` e `ZTA_PC_ITEM~SKU`; de desempenho em `ZTA_PC_ITEM_PED~ITEM_UUID`, `ZTA_PC_PEDIDO~CLIENTE_UUID`, `ZTA_PC_ENDERECO~CLIENTE_UUID`). São objetos de DDIC criados no ADT — não há fonte a entregar. |
| **B5** | Corrigido | `c_modo_trial` agora nasce `abap_false`. `ZCL_PC_AUTH` foi reescrita com verificação por atividade: `admin_pode_criar/alterar/excluir` (01/02/06) e `pedido_pode_criar/alterar/excluir/executar` (01/02/06/16); os três `get_global_authorizations` usam o método correspondente a cada operação. |
| R4, R6, R7 | Corrigidos | Cliente HTTP fechado também em erro; `CATCH cx_root` eliminado; cache do ViaCEP limitado a 100 entradas com descarte FIFO. |
| R1, R2, R3, R5, R8–R10 | Em aberto | Backlog de estabilização (ver seção 3). |

### Testes automatizados entregues

`ZCL_PC_UTIL` e `ZCL_PC_PAGAMENTO_SIM` receberam classes de teste ABAP Unit
(`*.clas.testclasses.abap`, `DURATION SHORT` / `RISK LEVEL HARMLESS`, sem banco):

| Classe de teste | Casos | Cobertura |
|---|---:|---|
| `ltcl_digitos_cpf` | 12 | normalização, CPF válido com e sem máscara, dígito verificador errado, sequência repetida, tamanho inválido, cálculo dos DV, formatação de CPF e telefone (10 e 11 dígitos) |
| `ltcl_email_imagem` | 9 | e-mail válido/inválido, foto opcional, PNG e JPEG com assinatura correta, MIME não permitido, extensão divergente e **conteúdo falsificado** (bytes JPEG declarados como PNG) |
| `ltcl_estoque_endereco` | 7 | faixas de status (0, negativo, 1, 10, 11) e formatação de endereço com/sem complemento |
| `ltcl_pagamento` | 14 | aprovação crédito/débito, bandeiras VISA/MASTERCARD/OUTRA, recusa por CVV 000, número com máscara, número curto/longo, CVV curto, método inválido, mês inválido, cartão expirado, validade no mês corrente e **garantia de que nenhum campo persistível contém o número completo** |

A data de referência do pagamento é injetada (`iv_data_referencia`), o que torna os testes de
validade determinísticos. Os testes ainda **não foram executados** — dependem da ativação no sistema.
