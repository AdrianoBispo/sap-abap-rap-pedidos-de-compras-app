*"* Test Classes da behavior pool ZBP_R_PC_PEDIDO (BO Pedido + filhos)
*"* Testes de integração por EML sobre test doubles: as tabelas do Pedido, do
*"* Item, do Cliente e do Reembolso (cl_cds_test_environment) e as de rascunho
*"* (cl_osql_test_environment) começam vazias em cada teste, sem gravar no banco.
*"* Nada é confirmado (sem COMMIT). O rascunho novo consome um número de ZPC_NR
*"* (intervalo 01). Ciclo completo com Save, edição e reembolso: ZCL_PC_UTIL
*"* (ltcl_edicao_pedido, ltcl_registro_pedido, ltcl_ciclo_pedido, ltcl_reembolso).

*"* Números T100 (Message Class ZPC_MSG) das mensagens de uma tabela REPORTED.
CLASS lcl_msgs DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS numeros
      IMPORTING it_reported       TYPE ANY TABLE
      RETURNING VALUE(rt_numeros) TYPE string_table.
ENDCLASS.


CLASS lcl_msgs IMPLEMENTATION.

  METHOD numeros.
    FIELD-SYMBOLS <lo_msg> TYPE REF TO if_abap_behv_message.

    LOOP AT it_reported ASSIGNING FIELD-SYMBOL(<ls_reported>).
      ASSIGN COMPONENT '%MSG' OF STRUCTURE <ls_reported> TO <lo_msg>.
      IF sy-subrc = 0 AND <lo_msg> IS BOUND.
        APPEND CONV string( <lo_msg>->if_t100_message~t100key-msgno ) TO rt_numeros.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


*"* Base: ambiente de test doubles, dados semeados e atalhos de EML.
CLASS lcl_base_pedido DEFINITION ABSTRACT.

  PROTECTED SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED EARLY zr_pc_pedido.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED EARLY zr_pc_pedido.
    TYPES ty_pedido   TYPE STRUCTURE FOR READ RESULT zr_pc_pedido\\Pedido.

    CLASS-DATA go_cds TYPE REF TO if_cds_test_environment.
    CLASS-DATA go_sql TYPE REF TO if_osql_test_environment.

    CLASS-METHODS criar_ambiente.
    CLASS-METHODS destruir_ambiente.
    CLASS-METHODS limpar_ambiente.

    "! Endereço principal do último cliente semeado.
    DATA mv_endereco TYPE sysuuid_x16.

    "! Cliente ativo já gravado (no double), com endereço principal validado.
    METHODS semear_cliente
      IMPORTING iv_ativo          TYPE abap_boolean DEFAULT abap_true
                iv_com_endereco   TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(rv_cliente) TYPE sysuuid_x16.
    "! Item ativo já gravado (no double), com saldo coerente.
    METHODS semear_item
      IMPORTING iv_estoque     TYPE i DEFAULT 100
                iv_reservada   TYPE i DEFAULT 0
                iv_ativo       TYPE abap_boolean DEFAULT abap_true
                iv_preco       TYPE zta_pc_item-preco_unitario DEFAULT '10.00'
      RETURNING VALUE(rv_item) TYPE sysuuid_x16.
    "! Pedido ativo já registrado (no double) com uma linha do item.
    METHODS semear_pedido
      IMPORTING iv_cliente       TYPE sysuuid_x16
                iv_item          TYPE sysuuid_x16
                iv_qtde          TYPE i DEFAULT 2
                iv_status        TYPE zif_pc_constants=>ty_status_pedido
                                 DEFAULT zif_pc_constants=>c_status_pedido-aberto
                iv_pagamento     TYPE zif_pc_constants=>ty_status_pagamento
                                 DEFAULT zif_pc_constants=>c_status_pagamento-pendente
      RETURNING VALUE(rv_pedido) TYPE sysuuid_x16.

    "! Rascunho de pedido novo, com uma linha do item (sem item: pedido vazio).
    METHODS criar_rascunho
      IMPORTING iv_cliente       TYPE sysuuid_x16
                iv_item          TYPE sysuuid_x16 OPTIONAL
                iv_qtde          TYPE i DEFAULT 1
      RETURNING VALUE(rv_pedido) TYPE sysuuid_x16.
    "! Executa o Prepare (validations do Save) no rascunho do pedido.
    METHODS preparar
      IMPORTING iv_pedido   TYPE sysuuid_x16
      EXPORTING es_failed   TYPE ty_failed
                es_reported TYPE ty_reported.
    METHODS ler_pedido
      IMPORTING iv_pedido        TYPE sysuuid_x16
                iv_rascunho      TYPE abap_boolean DEFAULT abap_false
      RETURNING VALUE(rs_pedido) TYPE ty_pedido.
    METHODS reservado
      IMPORTING iv_item       TYPE sysuuid_x16
      RETURNING VALUE(rv_qtd) TYPE i.

    METHODS pagar
      IMPORTING iv_pedido  TYPE sysuuid_x16
                iv_numero  TYPE csequence DEFAULT '4111111111111111'
                iv_cvv     TYPE csequence DEFAULT '123'
      EXPORTING ev_falhou  TYPE abap_boolean
                et_numeros TYPE string_table.
    METHODS aprovar
      IMPORTING iv_pedido  TYPE sysuuid_x16
      EXPORTING ev_falhou  TYPE abap_boolean
                et_numeros TYPE string_table.
    METHODS cancelar
      IMPORTING iv_pedido  TYPE sysuuid_x16
                iv_motivo  TYPE csequence DEFAULT 'QA'
      EXPORTING ev_falhou  TYPE abap_boolean
                et_numeros TYPE string_table.
ENDCLASS.


CLASS lcl_base_pedido IMPLEMENTATION.

  METHOD criar_ambiente.
    go_cds = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_PC_PEDIDO' )
                                         ( i_for_entity = 'ZR_PC_ITEM_PEDIDO' )
                                         ( i_for_entity = 'ZR_PC_PAGAMENTO' )
                                         ( i_for_entity = 'ZR_PC_PED_CLI_SNAP' )
                                         ( i_for_entity = 'ZR_PC_PED_ITEM_SNAP' )
                                         ( i_for_entity = 'ZR_PC_ITEM' )
                                         ( i_for_entity = 'ZR_PC_CLIENTE' )
                                         ( i_for_entity = 'ZR_PC_ENDERECO' )
                                         ( i_for_entity = 'ZR_PC_REEMBOLSO' )
                                         ( i_for_entity = 'ZR_PC_CODELIST' ) ) ).
    go_sql = cl_osql_test_environment=>create(
               i_dependency_list = VALUE #( ( 'ZTA_PC_PEDIDO_D' ) ( 'ZTA_PC_ITPED_D' ) ( 'ZTA_PC_PAGTO_D' )
                                            ( 'ZTA_PC_SNPCLI_D' ) ( 'ZTA_PC_SNPITM_D' ) ( 'ZTA_PC_ITEM_D' ) ) ).
  ENDMETHOD.

  METHOD destruir_ambiente.
    go_cds->destroy( ).
    go_sql->destroy( ).
  ENDMETHOD.

  METHOD limpar_ambiente.
    go_cds->clear_doubles( ).
    go_sql->clear_doubles( ).
  ENDMETHOD.

  METHOD semear_cliente.
    DATA lt_cli TYPE STANDARD TABLE OF zta_pc_cliente WITH EMPTY KEY.
    DATA lt_end TYPE STANDARD TABLE OF zta_pc_endereco WITH EMPTY KEY.

    rv_cliente = cl_system_uuid=>create_uuid_x16_static( ).
    lt_cli = VALUE #( ( client = sy-mandt cliente_uuid = rv_cliente cpf = '52998224725' nome = 'Cliente QA'
                        email = 'qa@teste.com' telefone = '11999999999' data_nascimento = '19900101'
                        cliente_ativo = iv_ativo score_cliente = 50 ) ).
    go_cds->insert_test_data( lt_cli ).

    CLEAR mv_endereco.
    CHECK iv_com_endereco = abap_true.
    mv_endereco = cl_system_uuid=>create_uuid_x16_static( ).
    lt_end = VALUE #( ( client = sy-mandt endereco_uuid = mv_endereco cep = '01310100' cliente_uuid = rv_cliente
                        logradouro = 'Av Paulista' numero = '1' bairro = 'Bela Vista' cidade = 'Sao Paulo'
                        uf = 'SP' estado = 'Sao Paulo' cep_status = zif_pc_constants=>c_status_cep-validado
                        endereco_principal = abap_true ) ).
    go_cds->insert_test_data( lt_end ).
  ENDMETHOD.

  METHOD semear_item.
    DATA lt_item TYPE STANDARD TABLE OF zta_pc_item WITH EMPTY KEY.

    rv_item = cl_system_uuid=>create_uuid_x16_static( ).
    lt_item = VALUE #( ( client = sy-mandt item_uuid = rv_item sku = 'SKU-ELE-0000000001' nome = 'Item QA'
                         categoria = 'ELETRONICOS' qtde_estoque = iv_estoque qtde_reservada = iv_reservada
                         qtde_disponivel = iv_estoque - iv_reservada
                         status_estoque = zcl_pc_util=>calcular_status_estoque( iv_estoque - iv_reservada )
                         currency = 'BRL' preco_unitario = iv_preco item_ativo = iv_ativo ) ).
    go_cds->insert_test_data( lt_item ).
  ENDMETHOD.

  METHOD semear_pedido.
    DATA lt_ped TYPE STANDARD TABLE OF zta_pc_pedido WITH EMPTY KEY.
    DATA lt_lin TYPE STANDARD TABLE OF zta_pc_item_ped WITH EMPTY KEY.

    rv_pedido = cl_system_uuid=>create_uuid_x16_static( ).
    lt_ped = VALUE #( ( client = sy-mandt pedido_uuid = rv_pedido numero_pedido = '9999999999'
                        cliente_uuid = iv_cliente endereco_uuid = mv_endereco
                        endereco_completo = 'Av Paulista, 1 - Bela Vista - Sao Paulo/SP - CEP 01310-100'
                        status_pedido = iv_status status_pagamento = iv_pagamento
                        currency = 'BRL' valor_total = iv_qtde * '10.00'
                        pedido_ativo_sem_hist = abap_true pedido_nao_finalizado = abap_true
                        pedido_nao_cancelado = abap_true ) ).
    lt_lin = VALUE #( ( client = sy-mandt item_pedido_uuid = cl_system_uuid=>create_uuid_x16_static( )
                        pedido_uuid = rv_pedido item_uuid = iv_item qtde_item_pedido = iv_qtde
                        currency = 'BRL' preco_unitario_snap = '10.00' valor_total = iv_qtde * '10.00' ) ).
    go_cds->insert_test_data( lt_ped ).
    go_cds->insert_test_data( lt_lin ).
  ENDMETHOD.

  METHOD criar_rascunho.
    IF iv_item IS INITIAL.
      MODIFY ENTITIES OF zr_pc_pedido
        ENTITY Pedido
          CREATE FIELDS ( ClienteUUID )
          WITH VALUE #( ( %cid = 'PED' %is_draft = if_abap_behv=>mk-on ClienteUUID = iv_cliente ) )
        MAPPED DATA(ls_mapped_vazio)
        FAILED DATA(ls_failed_vazio).
      cl_abap_unit_assert=>assert_initial( act = ls_failed_vazio msg = 'Falha ao criar o rascunho do pedido' ).
      rv_pedido = ls_mapped_vazio-pedido[ 1 ]-PedidoUUID.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        CREATE FIELDS ( ClienteUUID )
        WITH VALUE #( ( %cid = 'PED' %is_draft = if_abap_behv=>mk-on ClienteUUID = iv_cliente ) )
      ENTITY Pedido
        CREATE BY \_Itens FIELDS ( ItemUUID QtdeItemPedido )
        WITH VALUE #( ( %cid_ref = 'PED' %is_draft = if_abap_behv=>mk-on
                        %target  = VALUE #( ( %cid = 'LIN' %is_draft = if_abap_behv=>mk-on
                                              ItemUUID = iv_item QtdeItemPedido = iv_qtde ) ) ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao criar o rascunho do pedido' ).
    rv_pedido = ls_mapped-pedido[ 1 ]-PedidoUUID.
  ENDMETHOD.

  METHOD preparar.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE Prepare FROM VALUE #( ( %key-PedidoUUID = iv_pedido ) )
      FAILED es_failed
      REPORTED es_reported.
  ENDMETHOD.

  METHOD ler_pedido.
    READ ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        ALL FIELDS WITH VALUE #( ( PedidoUUID = iv_pedido
                                   %is_draft  = COND #( WHEN iv_rascunho = abap_true
                                                        THEN if_abap_behv=>mk-on
                                                        ELSE if_abap_behv=>mk-off ) ) )
      RESULT DATA(lt_ped).
    cl_abap_unit_assert=>assert_not_initial( act = lt_ped msg = 'Pedido não encontrado' ).
    rs_pedido = lt_ped[ 1 ].
  ENDMETHOD.

  METHOD reservado.
    READ ENTITIES OF zr_pc_item
      ENTITY Item
        FIELDS ( QtdeReservada )
        WITH VALUE #( ( ItemUUID = iv_item %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_item).
    IF lt_item IS NOT INITIAL.
      rv_qtd = lt_item[ 1 ]-QtdeReservada.
    ENDIF.
  ENDMETHOD.

  METHOD pagar.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE SimularPagamento FROM VALUE #( ( %key-PedidoUUID = iv_pedido %is_draft = if_abap_behv=>mk-off
                                                 %param-MetodoPagamento = zif_pc_constants=>c_metodo_pagamento-credito
                                                 %param-NumeroCartao    = iv_numero
                                                 %param-Validade        = '12/99'
                                                 %param-Cvv             = iv_cvv ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
    ev_falhou  = xsdbool( ls_failed-pedido IS NOT INITIAL ).
    et_numeros = lcl_msgs=>numeros( ls_reported-pedido ).
  ENDMETHOD.

  METHOD aprovar.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE AprovarPedido FROM VALUE #( ( %key-PedidoUUID = iv_pedido %is_draft = if_abap_behv=>mk-off ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
    ev_falhou  = xsdbool( ls_failed-pedido IS NOT INITIAL ).
    et_numeros = lcl_msgs=>numeros( ls_reported-pedido ).
  ENDMETHOD.

  METHOD cancelar.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE CancelarPedido FROM VALUE #( ( %key-PedidoUUID = iv_pedido %is_draft = if_abap_behv=>mk-off
                                               %param-MotivoCancelamento = iv_motivo ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
    ev_falhou  = xsdbool( ls_failed-pedido IS NOT INITIAL ).
    et_numeros = lcl_msgs=>numeros( ls_reported-pedido ).
  ENDMETHOD.

ENDCLASS.


*"* Rascunho de pedido: valores iniciais, total e validations do Save (Prepare).
CLASS ltcl_pedido_rascunho DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_pedido
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS nasce_aberto_com_endereco       FOR TESTING.
    METHODS calcula_valor_do_item_e_total   FOR TESTING.
    METHODS rascunho_valido_sem_erros       FOR TESTING.
    METHODS cliente_inativo_bloqueia        FOR TESTING.
    METHODS cliente_sem_endereco_bloqueia   FOR TESTING.
    METHODS pedido_sem_itens_bloqueia       FOR TESTING.
    METHODS estoque_insuficiente_bloqueia   FOR TESTING.
    METHODS item_inativo_bloqueia           FOR TESTING.
    METHODS quantidade_zero_bloqueia        FOR TESTING.
    METHODS item_sem_estoque_no_precheck    FOR TESTING.
ENDCLASS.


CLASS ltcl_pedido_rascunho IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    limpar_ambiente( ).
  ENDMETHOD.

  METHOD nasce_aberto_com_endereco.
    DATA(lv_cli) = semear_cliente( ).

    DATA(ls_ped) = ler_pedido( iv_pedido   = criar_rascunho( iv_cliente = lv_cli iv_item = semear_item( ) )
                               iv_rascunho = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = ls_ped-StatusPedido exp = zif_pc_constants=>c_status_pedido-aberto
                                        msg = 'Pedido novo nasce ABERTO' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-StatusPagamento
                                        exp = zif_pc_constants=>c_status_pagamento-pendente
                                        msg = 'Pagamento nasce PENDENTE' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-Currency exp = zif_pc_constants=>c_moeda_padrao msg = 'Moeda BRL' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-EnderecoUUID exp = mv_endereco
                                        msg = 'Pedido usa o endereço principal do cliente' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_ped-EnderecoPrincipalCompleto msg = 'Endereço formatado' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_ped-NumeroPedido msg = 'Número gerado já na criação' ).
  ENDMETHOD.

  METHOD calcula_valor_do_item_e_total.
    DATA(lv_ped) = criar_rascunho( iv_cliente = semear_cliente( )
                                   iv_item    = semear_item( iv_preco = '12.50' )
                                   iv_qtde    = 3 ).

    READ ENTITIES OF zr_pc_pedido
      ENTITY Pedido BY \_Itens
        FIELDS ( PrecoUnitarioSnapshot ValorTotal Currency )
        WITH VALUE #( ( PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-on ) )
      RESULT DATA(lt_lin).

    cl_abap_unit_assert=>assert_equals( act = lt_lin[ 1 ]-PrecoUnitarioSnapshot exp = '12.50'
                                        msg = 'Preço do item no momento da inclusão' ).
    cl_abap_unit_assert=>assert_equals( act = lt_lin[ 1 ]-ValorTotal exp = '37.50' msg = 'Quantidade x preço' ).
    cl_abap_unit_assert=>assert_equals( act = ler_pedido( iv_pedido = lv_ped iv_rascunho = abap_true )-ValorTotal
                                        exp = '37.50'
                                        msg = 'Total do pedido = soma das linhas' ).
  ENDMETHOD.

  METHOD rascunho_valido_sem_erros.
    preparar( EXPORTING iv_pedido = criar_rascunho( iv_cliente = semear_cliente( ) iv_item = semear_item( ) )
              IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_initial( act = ls_failed-pedido msg = 'Pedido válido não deve ser bloqueado' ).
    cl_abap_unit_assert=>assert_initial( act = ls_failed-itempedido msg = 'Linha válida não deve ser bloqueada' ).
  ENDMETHOD.

  METHOD cliente_inativo_bloqueia.
    preparar( EXPORTING iv_pedido = criar_rascunho( iv_cliente = semear_cliente( iv_ativo = abap_false )
                                                    iv_item    = semear_item( ) )
              IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-pedido msg = 'Cliente inativo não faz pedido' ).
    cl_abap_unit_assert=>assert_table_contains( line = `003` table = lcl_msgs=>numeros( ls_reported-pedido )
                                                msg = 'Mensagem 003 (cliente inativo)' ).
  ENDMETHOD.

  METHOD cliente_sem_endereco_bloqueia.
    preparar( EXPORTING iv_pedido = criar_rascunho( iv_cliente = semear_cliente( iv_com_endereco = abap_false )
                                                    iv_item    = semear_item( ) )
              IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-pedido msg = 'Sem endereço principal não registra' ).
    cl_abap_unit_assert=>assert_table_contains( line = `005` table = lcl_msgs=>numeros( ls_reported-pedido )
                                                msg = 'Mensagem 005 (sem endereço principal)' ).
  ENDMETHOD.

  METHOD pedido_sem_itens_bloqueia.
    preparar( EXPORTING iv_pedido = criar_rascunho( semear_cliente( ) )
              IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-pedido msg = 'Pedido vazio não registra' ).
    cl_abap_unit_assert=>assert_table_contains( line = `027` table = lcl_msgs=>numeros( ls_reported-pedido )
                                                msg = 'Mensagem 027 (pedido sem itens)' ).
  ENDMETHOD.

  METHOD estoque_insuficiente_bloqueia.
    preparar( EXPORTING iv_pedido = criar_rascunho( iv_cliente = semear_cliente( )
                                                    iv_item    = semear_item( iv_estoque = 5 )
                                                    iv_qtde    = 6 )
              IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-pedido msg = 'Quantidade acima do disponível não registra' ).
    cl_abap_unit_assert=>assert_table_contains( line = `011` table = lcl_msgs=>numeros( ls_reported-pedido )
                                                msg = 'Mensagem 011 (estoque insuficiente)' ).
  ENDMETHOD.

  METHOD item_inativo_bloqueia.
    preparar( EXPORTING iv_pedido = criar_rascunho( iv_cliente = semear_cliente( )
                                                    iv_item    = semear_item( iv_ativo = abap_false ) )
              IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-itempedido msg = 'Item inativo não pode ser pedido' ).
    cl_abap_unit_assert=>assert_table_contains( line = `013` table = lcl_msgs=>numeros( ls_reported-itempedido )
                                                msg = 'Mensagem 013 (item inativo)' ).
  ENDMETHOD.

  METHOD quantidade_zero_bloqueia.
    preparar( EXPORTING iv_pedido = criar_rascunho( iv_cliente = semear_cliente( )
                                                    iv_item    = semear_item( )
                                                    iv_qtde    = 0 )
              IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-itempedido msg = 'Linha com quantidade zero não registra' ).
  ENDMETHOD.

  METHOD item_sem_estoque_no_precheck.
    " O precheck da associação _Itens recusa a linha antes de qualquer determination
    DATA(lv_ped)  = criar_rascunho( semear_cliente( ) ).
    DATA(lv_item) = semear_item( iv_estoque = 3 iv_reservada = 3 ).

    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        CREATE BY \_Itens FIELDS ( ItemUUID QtdeItemPedido )
        WITH VALUE #( ( %tky    = VALUE #( PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-on )
                        %target = VALUE #( ( %cid = 'LIN' %is_draft = if_abap_behv=>mk-on
                                             ItemUUID = lv_item QtdeItemPedido = 1 ) ) ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-itempedido msg = 'Item sem disponível deve ser recusado' ).
    cl_abap_unit_assert=>assert_table_contains( line = `048` table = lcl_msgs=>numeros( ls_reported-itempedido )
                                                msg = 'Mensagem 048 (item sem estoque)' ).
  ENDMETHOD.

ENDCLASS.


*"* Ações sobre o pedido ativo: pagamento, aprovação e cancelamento.
CLASS ltcl_pedido_acoes DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_pedido
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS pagamento_dados_invalidos       FOR TESTING.
    METHODS pagamento_grava_so_mascara      FOR TESTING.
    METHODS pagamento_so_em_pedido_aberto   FOR TESTING.
    METHODS aprovar_gera_snapshots          FOR TESTING.
    METHODS aprovar_sem_reserva_recusado    FOR TESTING.
    METHODS cancelar_gera_snapshot          FOR TESTING.
    METHODS cancelar_finalizado_recusado    FOR TESTING.
ENDCLASS.


CLASS ltcl_pedido_acoes IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    limpar_ambiente( ).
  ENDMETHOD.

  METHOD pagamento_dados_invalidos.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli iv_item = semear_item( iv_reservada = 2 ) ).

    pagar( EXPORTING iv_pedido = lv_ped iv_numero = '1234'
           IMPORTING ev_falhou = DATA(lv_falhou) et_numeros = DATA(lt_numeros) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Cartão com 4 dígitos é erro de entrada' ).
    cl_abap_unit_assert=>assert_table_contains( line = `032` table = lt_numeros msg = 'Mensagem 032 (dados do cartão)' ).
    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-StatusPedido exp = zif_pc_constants=>c_status_pedido-aberto
                                        msg = 'Status não muda' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-StatusPagamento
                                        exp = zif_pc_constants=>c_status_pagamento-pendente
                                        msg = 'Pagamento segue PENDENTE' ).
  ENDMETHOD.

  METHOD pagamento_grava_so_mascara.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli iv_item = semear_item( iv_reservada = 2 ) ).

    pagar( EXPORTING iv_pedido = lv_ped IMPORTING ev_falhou = DATA(lv_falhou) ).
    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = 'Efetuar Pagamento falhou' ).

    READ ENTITIES OF zr_pc_pedido
      ENTITY Pedido BY \_Pagamento
        ALL FIELDS WITH VALUE #( ( PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_pag).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_pag ) exp = 1 msg = 'Uma tentativa de pagamento gravada' ).
    DATA(ls_pag) = lt_pag[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_pag-StatusPagamento exp = zif_pc_constants=>c_status_pagamento-aprovado
                                        msg = 'Pagamento APROVADO' ).
    cl_abap_unit_assert=>assert_equals( act = ls_pag-BandeiraCartao exp = 'VISA' msg = 'Bandeira' ).
    cl_abap_unit_assert=>assert_equals( act = ls_pag-Ultimos4DigitosCartao exp = '1111' msg = 'Últimos 4 dígitos' ).
    cl_abap_unit_assert=>assert_equals( act = ls_pag-CartaoMascarado exp = '**** **** **** 1111'
                                        msg = 'Só o número mascarado é gravado' ).
  ENDMETHOD.

  METHOD pagamento_so_em_pedido_aberto.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_ped) = semear_pedido( iv_cliente   = lv_cli
                                  iv_item      = semear_item( iv_reservada = 2 )
                                  iv_status    = zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                  iv_pagamento = zif_pc_constants=>c_status_pagamento-aprovado ).

    pagar( EXPORTING iv_pedido = lv_ped IMPORTING ev_falhou = DATA(lv_falhou) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Pedido já pago não aceita novo pagamento' ).
  ENDMETHOD.

  METHOD aprovar_gera_snapshots.
    DATA(lv_cli)  = semear_cliente( ).
    DATA(lv_item) = semear_item( iv_reservada = 2 ).
    DATA(lv_ped)  = semear_pedido( iv_cliente   = lv_cli
                                   iv_item      = lv_item
                                   iv_status    = zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                   iv_pagamento = zif_pc_constants=>c_status_pagamento-aprovado ).

    aprovar( EXPORTING iv_pedido = lv_ped IMPORTING ev_falhou = DATA(lv_falhou) ).
    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = 'Aprovar pedido falhou' ).

    READ ENTITIES OF zr_pc_pedido
      ENTITY Pedido BY \_ClienteSnapshot
        ALL FIELDS WITH VALUE #( ( PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_snap_cli)
      ENTITY Pedido BY \_ItensSnapshot
        ALL FIELDS WITH VALUE #( ( PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_snap_itm).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_snap_cli ) exp = 1 msg = 'Um snapshot do cliente' ).
    cl_abap_unit_assert=>assert_equals( act = lt_snap_cli[ 1 ]-MotivoSnapshot exp = 'FINALIZACAO' msg = 'Motivo' ).
    cl_abap_unit_assert=>assert_equals( act = lt_snap_cli[ 1 ]-Cpf exp = '52998224725' msg = 'CPF copiado do cliente' ).
    cl_abap_unit_assert=>assert_equals( act = lt_snap_cli[ 1 ]-Cep exp = '01310100' msg = 'CEP do endereço de entrega' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_snap_itm ) exp = 1 msg = 'Um snapshot por linha do pedido' ).
    cl_abap_unit_assert=>assert_equals( act = lt_snap_itm[ 1 ]-Quantidade exp = 2 msg = 'Quantidade da linha' ).
    cl_abap_unit_assert=>assert_equals( act = lt_snap_itm[ 1 ]-Sku exp = 'SKU-ELE-0000000001' msg = 'SKU copiado do item' ).
  ENDMETHOD.

  METHOD aprovar_sem_reserva_recusado.
    " Pedido pago cujo estoque não está reservado: a baixa seria inconsistente
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_ped) = semear_pedido( iv_cliente   = lv_cli
                                  iv_item      = semear_item( iv_reservada = 0 )
                                  iv_status    = zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                  iv_pagamento = zif_pc_constants=>c_status_pagamento-aprovado ).

    aprovar( EXPORTING iv_pedido = lv_ped IMPORTING ev_falhou = DATA(lv_falhou) et_numeros = DATA(lt_numeros) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Aprovar sem reserva deve falhar' ).
    cl_abap_unit_assert=>assert_table_contains( line = `038` table = lt_numeros msg = 'Mensagem 038 (reserva inconsistente)' ).
    cl_abap_unit_assert=>assert_equals( act = ler_pedido( lv_ped )-StatusPedido
                                        exp = zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                        msg = 'Status não muda' ).
  ENDMETHOD.

  METHOD cancelar_gera_snapshot.
    DATA(lv_cli)  = semear_cliente( ).
    DATA(lv_item) = semear_item( iv_reservada = 2 ).
    DATA(lv_ped)  = semear_pedido( iv_cliente = lv_cli iv_item = lv_item ).

    cancelar( EXPORTING iv_pedido = lv_ped IMPORTING ev_falhou = DATA(lv_falhou) ).
    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = 'Cancelar falhou' ).

    READ ENTITIES OF zr_pc_pedido
      ENTITY Pedido BY \_ClienteSnapshot
        FIELDS ( MotivoSnapshot ) WITH VALUE #( ( PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_snap_cli).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_snap_cli ) exp = 1 msg = 'Um snapshot do cliente' ).
    cl_abap_unit_assert=>assert_equals( act = lt_snap_cli[ 1 ]-MotivoSnapshot exp = 'CANCELAMENTO' msg = 'Motivo' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_item ) exp = 0 msg = 'Cancelar libera a reserva' ).
  ENDMETHOD.

  METHOD cancelar_finalizado_recusado.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_ped) = semear_pedido( iv_cliente   = lv_cli
                                  iv_item      = semear_item( )
                                  iv_status    = zif_pc_constants=>c_status_pedido-finalizado
                                  iv_pagamento = zif_pc_constants=>c_status_pagamento-aprovado ).

    cancelar( EXPORTING iv_pedido = lv_ped IMPORTING ev_falhou = DATA(lv_falhou) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Pedido FINALIZADO não pode ser cancelado' ).
    cl_abap_unit_assert=>assert_equals( act = ler_pedido( lv_ped )-StatusPedido
                                        exp = zif_pc_constants=>c_status_pedido-finalizado
                                        msg = 'Status não muda' ).
  ENDMETHOD.

ENDCLASS.
