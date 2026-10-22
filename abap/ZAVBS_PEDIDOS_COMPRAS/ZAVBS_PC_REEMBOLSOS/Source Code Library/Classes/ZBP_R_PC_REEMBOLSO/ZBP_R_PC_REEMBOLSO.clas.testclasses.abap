*"* Test Classes da behavior pool ZBP_R_PC_REEMBOLSO (BO Reembolso)
*"* Testes de integração por EML sobre test doubles: as tabelas do Reembolso e
*"* do Pedido, com seus filhos, Item e Cliente (cl_cds_test_environment) e as
*"* de rascunho do Pedido (cl_osql_test_environment) começam vazias em cada
*"* teste, sem gravar no banco. Nada é confirmado (sem COMMIT).
*"* Fluxo de cancelamento com pedido pago: ZCL_PC_UTIL, ltcl_reembolso.

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


*"* Decisão da solicitação de reembolso (aprovar ou rejeitar).
CLASS ltcl_reembolso_decisao DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_reembolso TYPE STRUCTURE FOR READ RESULT zr_pc_reembolso\\Reembolso.
    TYPES ty_pedido    TYPE STRUCTURE FOR READ RESULT zr_pc_pedido\\Pedido.

    CLASS-DATA go_cds TYPE REF TO if_cds_test_environment.
    CLASS-DATA go_sql TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    "! Pedido pago em PROCESSANDO_REEMBOLSO (estoque reservado) e a solicitação.
    METHODS semear_solicitacao
      IMPORTING iv_status_reembolso TYPE zif_pc_constants=>ty_status_reembolso
                                    DEFAULT zif_pc_constants=>c_status_reembolso-pendente
                iv_status_pedido    TYPE zif_pc_constants=>ty_status_pedido
                                    DEFAULT zif_pc_constants=>c_status_pedido-processando_reembolso
      EXPORTING ev_reembolso        TYPE sysuuid_x16
                ev_pedido           TYPE sysuuid_x16
                ev_item             TYPE sysuuid_x16.
    METHODS decidir
      IMPORTING iv_reembolso TYPE sysuuid_x16
                iv_aprovar   TYPE abap_boolean
                iv_motivo    TYPE csequence DEFAULT 'Analisado pelo QA'
      EXPORTING ev_falhou    TYPE abap_boolean
                et_numeros   TYPE string_table.
    METHODS ler_reembolso
      IMPORTING iv_reembolso        TYPE sysuuid_x16
      RETURNING VALUE(rs_reembolso) TYPE ty_reembolso.
    METHODS ler_pedido
      IMPORTING iv_pedido        TYPE sysuuid_x16
      RETURNING VALUE(rs_pedido) TYPE ty_pedido.
    METHODS reservado
      IMPORTING iv_item       TYPE sysuuid_x16
      RETURNING VALUE(rv_qtd) TYPE i.

    METHODS aprovar_registra_decisao      FOR TESTING.
    METHODS rejeitar_registra_motivo      FOR TESTING.
    METHODS aprovar_ja_decidido_recusado  FOR TESTING.
    METHODS rejeitar_ja_decidido_recusado FOR TESTING.
    METHODS aprovar_pedido_fora_do_status FOR TESTING.
ENDCLASS.


CLASS ltcl_reembolso_decisao IMPLEMENTATION.

  METHOD class_setup.
    go_cds = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_PC_REEMBOLSO' )
                                         ( i_for_entity = 'ZR_PC_PEDIDO' )
                                         ( i_for_entity = 'ZR_PC_ITEM_PEDIDO' )
                                         ( i_for_entity = 'ZR_PC_PAGAMENTO' )
                                         ( i_for_entity = 'ZR_PC_PED_CLI_SNAP' )
                                         ( i_for_entity = 'ZR_PC_PED_ITEM_SNAP' )
                                         ( i_for_entity = 'ZR_PC_ITEM' )
                                         ( i_for_entity = 'ZR_PC_CLIENTE' )
                                         ( i_for_entity = 'ZR_PC_ENDERECO' ) ) ).
    go_sql = cl_osql_test_environment=>create(
               i_dependency_list = VALUE #( ( 'ZTA_PC_PEDIDO_D' ) ( 'ZTA_PC_ITPED_D' ) ( 'ZTA_PC_PAGTO_D' )
                                            ( 'ZTA_PC_SNPCLI_D' ) ( 'ZTA_PC_SNPITM_D' ) ( 'ZTA_PC_ITEM_D' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_cds->destroy( ).
    go_sql->destroy( ).
  ENDMETHOD.

  METHOD setup.
    go_cds->clear_doubles( ).
    go_sql->clear_doubles( ).
  ENDMETHOD.

  METHOD semear_solicitacao.
    DATA lt_cli  TYPE STANDARD TABLE OF zta_pc_cliente WITH EMPTY KEY.
    DATA lt_item TYPE STANDARD TABLE OF zta_pc_item WITH EMPTY KEY.
    DATA lt_ped  TYPE STANDARD TABLE OF zta_pc_pedido WITH EMPTY KEY.
    DATA lt_lin  TYPE STANDARD TABLE OF zta_pc_item_ped WITH EMPTY KEY.
    DATA lt_reb  TYPE STANDARD TABLE OF zta_pc_reembolso WITH EMPTY KEY.

    DATA(lv_cliente) = cl_system_uuid=>create_uuid_x16_static( ).
    ev_item      = cl_system_uuid=>create_uuid_x16_static( ).
    ev_pedido    = cl_system_uuid=>create_uuid_x16_static( ).
    ev_reembolso = cl_system_uuid=>create_uuid_x16_static( ).

    lt_cli = VALUE #( ( client = sy-mandt cliente_uuid = lv_cliente cpf = '52998224725' nome = 'Cliente QA'
                        email = 'qa@teste.com' telefone = '11999999999' data_nascimento = '19900101'
                        cliente_ativo = abap_true ) ).
    lt_item = VALUE #( ( client = sy-mandt item_uuid = ev_item sku = 'SKU-ELE-0000000001' nome = 'Item QA'
                         categoria = 'ELETRONICOS' qtde_estoque = 100 qtde_reservada = 2 qtde_disponivel = 98
                         status_estoque = zif_pc_constants=>c_status_estoque-em_estoque
                         currency = 'BRL' preco_unitario = '10.00' item_ativo = abap_true ) ).
    lt_ped = VALUE #( ( client = sy-mandt pedido_uuid = ev_pedido numero_pedido = '9999999999'
                        cliente_uuid = lv_cliente status_pedido = iv_status_pedido
                        status_pagamento = zif_pc_constants=>c_status_pagamento-aprovado
                        motivo_cancelamento = 'Desistência' currency = 'BRL' valor_total = '20.00' ) ).
    lt_lin = VALUE #( ( client = sy-mandt item_pedido_uuid = cl_system_uuid=>create_uuid_x16_static( )
                        pedido_uuid = ev_pedido item_uuid = ev_item qtde_item_pedido = 2
                        currency = 'BRL' preco_unitario_snap = '10.00' valor_total = '20.00' ) ).
    lt_reb = VALUE #( ( client = sy-mandt reembolso_uuid = ev_reembolso pedido_uuid = ev_pedido
                        numero_pedido = '9999999999' cliente_uuid = lv_cliente
                        status_reembolso = iv_status_reembolso
                        status_pedido_anterior = zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                        currency = 'BRL' valor_reembolso = '20.00' motivo_solicitacao = 'Desistência' ) ).

    go_cds->insert_test_data( lt_cli ).
    go_cds->insert_test_data( lt_item ).
    go_cds->insert_test_data( lt_ped ).
    go_cds->insert_test_data( lt_lin ).
    go_cds->insert_test_data( lt_reb ).
  ENDMETHOD.

  METHOD decidir.
    DATA ls_failed   TYPE RESPONSE FOR FAILED EARLY zr_pc_reembolso.
    DATA ls_reported TYPE RESPONSE FOR REPORTED EARLY zr_pc_reembolso.

    IF iv_aprovar = abap_true.
      MODIFY ENTITIES OF zr_pc_reembolso
        ENTITY Reembolso
          EXECUTE AprovarReembolso FROM VALUE #( ( %key-ReembolsoUUID = iv_reembolso
                                                   %param-MotivoDecisao = iv_motivo ) )
        FAILED ls_failed
        REPORTED ls_reported.
    ELSE.
      MODIFY ENTITIES OF zr_pc_reembolso
        ENTITY Reembolso
          EXECUTE RejeitarReembolso FROM VALUE #( ( %key-ReembolsoUUID = iv_reembolso
                                                    %param-MotivoDecisao = iv_motivo ) )
        FAILED ls_failed
        REPORTED ls_reported.
    ENDIF.

    ev_falhou  = xsdbool( ls_failed-reembolso IS NOT INITIAL ).
    et_numeros = lcl_msgs=>numeros( ls_reported-reembolso ).
  ENDMETHOD.

  METHOD ler_reembolso.
    READ ENTITIES OF zr_pc_reembolso
      ENTITY Reembolso
        ALL FIELDS WITH VALUE #( ( ReembolsoUUID = iv_reembolso ) )
      RESULT DATA(lt_reb).
    cl_abap_unit_assert=>assert_not_initial( act = lt_reb msg = 'Reembolso não encontrado' ).
    rs_reembolso = lt_reb[ 1 ].
  ENDMETHOD.

  METHOD ler_pedido.
    READ ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        ALL FIELDS WITH VALUE #( ( PedidoUUID = iv_pedido %is_draft = if_abap_behv=>mk-off ) )
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

  METHOD aprovar_registra_decisao.
    semear_solicitacao( IMPORTING ev_reembolso = DATA(lv_reb) ev_pedido = DATA(lv_ped) ev_item = DATA(lv_item) ).

    decidir( EXPORTING iv_reembolso = lv_reb iv_aprovar = abap_true IMPORTING ev_falhou = DATA(lv_falhou) ).
    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = 'Aprovar reembolso falhou' ).

    DATA(ls_reb) = ler_reembolso( lv_reb ).
    cl_abap_unit_assert=>assert_equals( act = ls_reb-StatusReembolso exp = zif_pc_constants=>c_status_reembolso-aprovado
                                        msg = 'Reembolso APROVADO' ).
    cl_abap_unit_assert=>assert_equals( act = condense( ls_reb-MotivoDecisao ) exp = `Analisado pelo QA`
                                        msg = 'Motivo da decisão gravado' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_reb-DataDecisao msg = 'Data da decisão gravada' ).
    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-StatusPedido exp = zif_pc_constants=>c_status_pedido-cancelado
                                        msg = 'Pedido CANCELADO na mesma transação' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-StatusPagamento
                                        exp = zif_pc_constants=>c_status_pagamento-devolvido
                                        msg = 'Pagamento DEVOLVIDO' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_item ) exp = 0 msg = 'Reserva liberada' ).
  ENDMETHOD.

  METHOD rejeitar_registra_motivo.
    semear_solicitacao( IMPORTING ev_reembolso = DATA(lv_reb) ev_pedido = DATA(lv_ped) ev_item = DATA(lv_item) ).

    decidir( EXPORTING iv_reembolso = lv_reb iv_aprovar = abap_false iv_motivo = 'Fora do prazo'
             IMPORTING ev_falhou = DATA(lv_falhou) ).
    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = 'Rejeitar reembolso falhou' ).

    DATA(ls_reb) = ler_reembolso( lv_reb ).
    cl_abap_unit_assert=>assert_equals( act = ls_reb-StatusReembolso exp = zif_pc_constants=>c_status_reembolso-rejeitado
                                        msg = 'Reembolso REJEITADO' ).
    cl_abap_unit_assert=>assert_equals( act = condense( ls_reb-MotivoDecisao ) exp = `Fora do prazo`
                                        msg = 'Motivo da rejeição gravado' ).
    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-StatusPedido
                                        exp = zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                        msg = 'Pedido volta ao status anterior' ).
    cl_abap_unit_assert=>assert_initial( act = ls_ped-MotivoCancelamento msg = 'Motivo do cancelamento é limpo' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_item ) exp = 2 msg = 'Reserva mantida' ).
  ENDMETHOD.

  METHOD aprovar_ja_decidido_recusado.
    semear_solicitacao( EXPORTING iv_status_reembolso = zif_pc_constants=>c_status_reembolso-rejeitado
                        IMPORTING ev_reembolso = DATA(lv_reb) ).

    decidir( EXPORTING iv_reembolso = lv_reb iv_aprovar = abap_true IMPORTING ev_falhou = DATA(lv_falhou) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Só a solicitação PENDENTE pode ser decidida' ).
    cl_abap_unit_assert=>assert_equals( act = ler_reembolso( lv_reb )-StatusReembolso
                                        exp = zif_pc_constants=>c_status_reembolso-rejeitado
                                        msg = 'Decisão anterior mantida' ).
  ENDMETHOD.

  METHOD rejeitar_ja_decidido_recusado.
    semear_solicitacao( EXPORTING iv_status_reembolso = zif_pc_constants=>c_status_reembolso-aprovado
                        IMPORTING ev_reembolso = DATA(lv_reb) ).

    decidir( EXPORTING iv_reembolso = lv_reb iv_aprovar = abap_false IMPORTING ev_falhou = DATA(lv_falhou) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Só a solicitação PENDENTE pode ser decidida' ).
  ENDMETHOD.

  METHOD aprovar_pedido_fora_do_status.
    " Pedido que já saiu de PROCESSANDO_REEMBOLSO: o BO Pedido recusa e a
    " solicitação continua PENDENTE (tudo na mesma transação)
    semear_solicitacao( EXPORTING iv_status_pedido = zif_pc_constants=>c_status_pedido-cancelado
                        IMPORTING ev_reembolso = DATA(lv_reb) ).

    decidir( EXPORTING iv_reembolso = lv_reb iv_aprovar = abap_true IMPORTING ev_falhou = DATA(lv_falhou) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Pedido fora de PROCESSANDO_REEMBOLSO deve falhar' ).
    cl_abap_unit_assert=>assert_equals( act = ler_reembolso( lv_reb )-StatusReembolso
                                        exp = zif_pc_constants=>c_status_reembolso-pendente
                                        msg = 'Reembolso segue PENDENTE' ).
  ENDMETHOD.

ENDCLASS.
