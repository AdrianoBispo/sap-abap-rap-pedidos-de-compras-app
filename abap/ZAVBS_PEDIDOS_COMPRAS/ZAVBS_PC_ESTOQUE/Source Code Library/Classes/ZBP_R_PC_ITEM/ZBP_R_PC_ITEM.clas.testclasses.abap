*"* Test Classes da behavior pool ZBP_R_PC_ITEM (BO Item de Estoque)
*"* Testes de integração por EML sobre test doubles: as tabelas do Item, dos
*"* pedidos e da CodeList (cl_cds_test_environment) e as de rascunho
*"* (cl_osql_test_environment) começam vazias em cada teste, sem gravar no banco.
*"* Nada é confirmado (sem COMMIT): o que se verifica é o buffer transacional.
*"* O Prepare executa GerarSku, que consome um número de ZPC_NR (intervalo 02).
*"* Geração do SKU: ZCL_PC_UTIL, ltcl_sku_item.

*"* Números T100 (Message Class ZPC_MSG) das mensagens de uma tabela REPORTED.
"! Apoio dos testes: números T100 das mensagens de um REPORTED.
CLASS lcl_msgs DEFINITION FINAL.
  PUBLIC SECTION.
    "! Números T100 (Message Class ZPC_MSG) das mensagens com %msg.
    "! @parameter it_reported | Tabela REPORTED de qualquer entidade
    "! @parameter rt_numeros | Números das mensagens (ex.: 014)
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
"! Base dos testes do BO {@link ZR_PC_ITEM}: ambiente de test doubles, dados
"! semeados e atalhos de EML usados pelas classes de teste.
CLASS lcl_base_item DEFINITION ABSTRACT FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PROTECTED SECTION.
    "! FAILED do BO Item
    TYPES ty_failed   TYPE RESPONSE FOR FAILED EARLY zr_pc_item.
    "! REPORTED do BO Item
    TYPES ty_reported TYPE RESPONSE FOR REPORTED EARLY zr_pc_item.
    "! Item lido por READ ENTITIES
    TYPES ty_item     TYPE STRUCTURE FOR READ RESULT zr_pc_item\\Item.

    CONSTANTS:
      "! Actions de movimento usadas em {@link .METH:movimentar}
      BEGIN OF c_mov,
        "! ReservarEstoque
        reservar TYPE c LENGTH 1 VALUE 'R',
        "! LiberarReserva
        liberar  TYPE c LENGTH 1 VALUE 'L',
        "! BaixarEstoque
        baixar   TYPE c LENGTH 1 VALUE 'B',
      END OF c_mov.

    "! Doubles das entidades CDS (Item, pedidos e CodeList)
    CLASS-DATA go_cds TYPE REF TO if_cds_test_environment.
    "! Doubles das tabelas de rascunho
    CLASS-DATA go_sql TYPE REF TO if_osql_test_environment.

    "! Cria os doubles (uma vez por classe de teste).
    CLASS-METHODS criar_ambiente.
    "! Destrói os doubles ao final da classe de teste.
    CLASS-METHODS destruir_ambiente.
    "! Limpa os doubles e cadastra a categoria ELETRONICOS na CodeList.
    CLASS-METHODS limpar_ambiente.

    "! Item ativo já gravado (no double), com saldo coerente.
    METHODS semear_item
      IMPORTING iv_estoque     TYPE i
                iv_reservada   TYPE i DEFAULT 0
                iv_ativo       TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(rv_item) TYPE sysuuid_x16.
    "! Pedido ativo com uma linha do item (no double).
    METHODS semear_pedido_com_item
      IMPORTING iv_item   TYPE sysuuid_x16
                iv_status TYPE zif_pc_constants=>ty_status_pedido DEFAULT zif_pc_constants=>c_status_pedido-aberto.
    "! Linha de pedido ainda em rascunho com o item (tabela draft no double).
    METHODS semear_item_pedido_rascunho
      IMPORTING iv_item TYPE sysuuid_x16.

    "! Executa ReservarEstoque, LiberarReserva ou BaixarEstoque no item ativo.
    METHODS movimentar
      IMPORTING iv_item     TYPE sysuuid_x16
                iv_mov      TYPE c
                iv_qtde     TYPE i
      EXPORTING ev_falhou   TYPE abap_boolean
                et_numeros  TYPE string_table.
    "! Lê o item ativo (ou o rascunho) pelo BO.
    METHODS ler_item
      IMPORTING iv_item        TYPE sysuuid_x16
                iv_rascunho    TYPE abap_boolean DEFAULT abap_false
      RETURNING VALUE(rs_item) TYPE ty_item.
    "! Rascunho de item novo (sem moeda: a determination assume BRL).
    METHODS criar_rascunho
      IMPORTING iv_categoria   TYPE csequence DEFAULT 'ELETRONICOS'
                iv_estoque     TYPE i DEFAULT 5
                iv_preco       TYPE zta_pc_item-preco_unitario DEFAULT '10.00'
      RETURNING VALUE(rv_item) TYPE sysuuid_x16.
    "! Executa o Prepare (determinations e validations do Save) no rascunho.
    METHODS preparar
      IMPORTING iv_item     TYPE sysuuid_x16
      EXPORTING es_failed   TYPE ty_failed
                es_reported TYPE ty_reported.
ENDCLASS.


CLASS lcl_base_item IMPLEMENTATION.

  METHOD criar_ambiente.
    go_cds = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_PC_ITEM' )
                                         ( i_for_entity = 'ZR_PC_CODELIST' )
                                         ( i_for_entity = 'ZR_PC_PEDIDO' )
                                         ( i_for_entity = 'ZR_PC_ITEM_PEDIDO' ) ) ).
    go_sql = cl_osql_test_environment=>create(
               i_dependency_list = VALUE #( ( 'ZTA_PC_ITEM_D' ) ( 'ZTA_PC_ITPED_D' ) ) ).
  ENDMETHOD.

  METHOD destruir_ambiente.
    go_cds->destroy( ).
    go_sql->destroy( ).
  ENDMETHOD.

  METHOD limpar_ambiente.
    DATA lt_cod TYPE STANDARD TABLE OF zta_pc_codelist WITH EMPTY KEY.

    go_cds->clear_doubles( ).
    go_sql->clear_doubles( ).
    lt_cod = VALUE #( ( client = sy-mandt lista = zif_pc_constants=>c_codelist-categoria codigo = 'ELETRONICOS'
                        descricao = 'Eletrônicos' ordem = 1 ) ).
    go_cds->insert_test_data( lt_cod ).
  ENDMETHOD.

  METHOD semear_item.
    DATA lt_item TYPE STANDARD TABLE OF zta_pc_item WITH EMPTY KEY.

    rv_item = cl_system_uuid=>create_uuid_x16_static( ).
    lt_item = VALUE #( ( client = sy-mandt item_uuid = rv_item sku = 'SKU-ELE-0000000001' nome = 'Item QA'
                         categoria = 'ELETRONICOS' qtde_estoque = iv_estoque qtde_reservada = iv_reservada
                         qtde_disponivel = iv_estoque - iv_reservada
                         status_estoque = zcl_pc_util=>calcular_status_estoque( iv_estoque - iv_reservada )
                         currency = 'BRL' preco_unitario = '10.00' item_ativo = iv_ativo ) ).
    go_cds->insert_test_data( lt_item ).
  ENDMETHOD.

  METHOD semear_pedido_com_item.
    DATA lt_ped TYPE STANDARD TABLE OF zta_pc_pedido WITH EMPTY KEY.
    DATA lt_lin TYPE STANDARD TABLE OF zta_pc_item_ped WITH EMPTY KEY.

    DATA(lv_pedido) = cl_system_uuid=>create_uuid_x16_static( ).
    lt_ped = VALUE #( ( client = sy-mandt pedido_uuid = lv_pedido numero_pedido = '9999999999'
                        cliente_uuid = cl_system_uuid=>create_uuid_x16_static( )
                        status_pedido = iv_status currency = 'BRL' ) ).
    lt_lin = VALUE #( ( client = sy-mandt item_pedido_uuid = cl_system_uuid=>create_uuid_x16_static( )
                        pedido_uuid = lv_pedido item_uuid = iv_item qtde_item_pedido = 1 currency = 'BRL' ) ).
    go_cds->insert_test_data( lt_ped ).
    go_cds->insert_test_data( lt_lin ).
  ENDMETHOD.

  METHOD semear_item_pedido_rascunho.
    DATA lt_lin TYPE STANDARD TABLE OF zta_pc_itped_d WITH EMPTY KEY.

    lt_lin = VALUE #( ( mandt = sy-mandt itempedidouuid = cl_system_uuid=>create_uuid_x16_static( )
                        pedidouuid = cl_system_uuid=>create_uuid_x16_static( ) itemuuid = iv_item
                        qtdeitempedido = 1 ) ).
    go_sql->insert_test_data( lt_lin ).
  ENDMETHOD.

  METHOD movimentar.
    DATA ls_failed   TYPE ty_failed.
    DATA ls_reported TYPE ty_reported.

    CASE iv_mov.
      WHEN c_mov-reservar.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE ReservarEstoque FROM VALUE #( ( %key-ItemUUID = iv_item %is_draft = if_abap_behv=>mk-off
                                                    %param-Quantidade = iv_qtde ) )
          FAILED ls_failed
          REPORTED ls_reported.
      WHEN c_mov-liberar.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE LiberarReserva FROM VALUE #( ( %key-ItemUUID = iv_item %is_draft = if_abap_behv=>mk-off
                                                   %param-Quantidade = iv_qtde ) )
          FAILED ls_failed
          REPORTED ls_reported.
      WHEN c_mov-baixar.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE BaixarEstoque FROM VALUE #( ( %key-ItemUUID = iv_item %is_draft = if_abap_behv=>mk-off
                                                  %param-Quantidade = iv_qtde ) )
          FAILED ls_failed
          REPORTED ls_reported.
    ENDCASE.

    ev_falhou  = xsdbool( ls_failed-item IS NOT INITIAL ).
    et_numeros = lcl_msgs=>numeros( ls_reported-item ).
  ENDMETHOD.

  METHOD ler_item.
    READ ENTITIES OF zr_pc_item
      ENTITY Item
        ALL FIELDS WITH VALUE #( ( ItemUUID  = iv_item
                                   %is_draft = COND #( WHEN iv_rascunho = abap_true
                                                       THEN if_abap_behv=>mk-on
                                                       ELSE if_abap_behv=>mk-off ) ) )
      RESULT DATA(lt_item).
    cl_abap_unit_assert=>assert_not_initial( act = lt_item msg = 'Item não encontrado' ).
    rs_item = lt_item[ 1 ].
  ENDMETHOD.

  METHOD criar_rascunho.
    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        CREATE FIELDS ( Nome Categoria QtdeEstoque PrecoUnitario )
        WITH VALUE #( ( %cid = 'ITM' %is_draft = if_abap_behv=>mk-on
                        Nome = 'Item QA' Categoria = iv_categoria QtdeEstoque = iv_estoque
                        PrecoUnitario = iv_preco ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao criar o rascunho do item' ).
    rv_item = ls_mapped-item[ 1 ]-ItemUUID.
  ENDMETHOD.

  METHOD preparar.
    " EXECUTE Prepare por EML não devolve as falhas das validations nesta LUW;
    " o Activate executa o Prepare do rascunho e devolve FAILED/REPORTED
    " (no REPORTED só a mensagem genérica do framework, sem o número T100).
    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        EXECUTE Activate FROM VALUE #( ( %cid = 'ACT' %key-ItemUUID = iv_item ) )
      FAILED es_failed
      REPORTED es_reported.
  ENDMETHOD.

ENDCLASS.


*"* Reserva, liberação e baixa de estoque (actions usadas pelo BO Pedido).
"! Reserva, liberação e baixa de estoque: actions internas do BO Item
"! chamadas pelo BO {@link ZR_PC_PEDIDO}.
CLASS ltcl_item_movimentacao DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_item
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Cria os doubles da classe.
    CLASS-METHODS class_setup.
    "! Destrói os doubles da classe.
    CLASS-METHODS class_teardown.
    "! Doubles limpos antes de cada teste.
    METHODS setup.

    "! Reserva dentro do disponível aumenta QtdeReservada.
    METHODS reserva_dentro_do_disponivel  FOR TESTING.
    "! A reserva recalcula QtdeDisponivel e StatusEstoque.
    METHODS reserva_recalcula_status      FOR TESTING.
    "! Reserva acima do disponível é recusada (011).
    METHODS reserva_acima_do_disponivel   FOR TESTING.
    "! Item inativo não pode ser reservado (013).
    METHODS reserva_item_inativo          FOR TESTING.
    "! Movimento com quantidade zero é recusado (028).
    METHODS quantidade_zero_recusada      FOR TESTING.
    "! Liberar parte da reserva diminui QtdeReservada.
    METHODS libera_parte_da_reserva       FOR TESTING.
    "! Liberar mais do que o reservado é recusado (038).
    METHODS libera_acima_da_reserva       FOR TESTING.
    "! Baixa diminui estoque e reserva.
    METHODS baixa_estoque_e_reserva       FOR TESTING.
    "! Baixa sem reserva suficiente é recusada (038).
    METHODS baixa_sem_reserva             FOR TESTING.
ENDCLASS.


CLASS ltcl_item_movimentacao IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    limpar_ambiente( ).
  ENDMETHOD.

  METHOD reserva_dentro_do_disponivel.
    DATA(lv_item) = semear_item( 20 ).

    movimentar( EXPORTING iv_item = lv_item iv_mov = c_mov-reservar iv_qtde = 5
                IMPORTING ev_falhou = DATA(lv_falhou) ).

    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = 'Reserva dentro do disponível deve passar' ).
    DATA(ls_item) = ler_item( lv_item ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeReservada exp = 5 msg = 'Reservada' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeDisponivel exp = 15 msg = 'Disponível = estoque - reservada' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeEstoque exp = 20 msg = 'Reserva não muda o estoque físico' ).
  ENDMETHOD.

  METHOD reserva_recalcula_status.
    DATA(lv_item) = semear_item( 12 ).

    movimentar( EXPORTING iv_item = lv_item iv_mov = c_mov-reservar iv_qtde = 5
                IMPORTING ev_falhou = DATA(lv_falhou) ).

    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = 'Reserva deve passar' ).
    cl_abap_unit_assert=>assert_equals( act = ler_item( lv_item )-StatusEstoque
                                        exp = zif_pc_constants=>c_status_estoque-acabando
                                        msg = 'Disponível 7 => ACABANDO' ).
  ENDMETHOD.

  METHOD reserva_acima_do_disponivel.
    DATA(lv_item) = semear_item( iv_estoque = 10 iv_reservada = 8 ).

    movimentar( EXPORTING iv_item = lv_item iv_mov = c_mov-reservar iv_qtde = 3
                IMPORTING ev_falhou = DATA(lv_falhou) et_numeros = DATA(lt_numeros) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Reserva acima do disponível deve falhar' ).
    cl_abap_unit_assert=>assert_table_contains( line = `011` table = lt_numeros msg = 'Mensagem 011 (estoque insuficiente)' ).
    cl_abap_unit_assert=>assert_equals( act = ler_item( lv_item )-QtdeReservada exp = 8 msg = 'Reserva não muda' ).
  ENDMETHOD.

  METHOD reserva_item_inativo.
    DATA(lv_item) = semear_item( iv_estoque = 10 iv_ativo = abap_false ).

    movimentar( EXPORTING iv_item = lv_item iv_mov = c_mov-reservar iv_qtde = 1
                IMPORTING ev_falhou = DATA(lv_falhou) et_numeros = DATA(lt_numeros) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Item inativo não pode ser reservado' ).
    cl_abap_unit_assert=>assert_table_contains( line = `013` table = lt_numeros msg = 'Mensagem 013 (item inativo)' ).
  ENDMETHOD.

  METHOD quantidade_zero_recusada.
    DATA(lv_item) = semear_item( 10 ).

    movimentar( EXPORTING iv_item = lv_item iv_mov = c_mov-reservar iv_qtde = 0
                IMPORTING ev_falhou = DATA(lv_falhou) et_numeros = DATA(lt_numeros) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Quantidade zero deve falhar' ).
    cl_abap_unit_assert=>assert_table_contains( line = `028` table = lt_numeros msg = 'Mensagem 028 (quantidade inválida)' ).
  ENDMETHOD.

  METHOD libera_parte_da_reserva.
    DATA(lv_item) = semear_item( iv_estoque = 10 iv_reservada = 5 ).

    movimentar( EXPORTING iv_item = lv_item iv_mov = c_mov-liberar iv_qtde = 2
                IMPORTING ev_falhou = DATA(lv_falhou) ).

    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = 'Liberação deve passar' ).
    DATA(ls_item) = ler_item( lv_item ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeReservada exp = 3 msg = 'Reservada' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeDisponivel exp = 7 msg = 'Disponível' ).
  ENDMETHOD.

  METHOD libera_acima_da_reserva.
    DATA(lv_item) = semear_item( iv_estoque = 10 iv_reservada = 1 ).

    movimentar( EXPORTING iv_item = lv_item iv_mov = c_mov-liberar iv_qtde = 2
                IMPORTING ev_falhou = DATA(lv_falhou) et_numeros = DATA(lt_numeros) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Liberar mais que o reservado deve falhar' ).
    cl_abap_unit_assert=>assert_table_contains( line = `038` table = lt_numeros msg = 'Mensagem 038 (reserva inconsistente)' ).
    cl_abap_unit_assert=>assert_equals( act = ler_item( lv_item )-QtdeReservada exp = 1 msg = 'Reserva não muda' ).
  ENDMETHOD.

  METHOD baixa_estoque_e_reserva.
    DATA(lv_item) = semear_item( iv_estoque = 20 iv_reservada = 5 ).

    movimentar( EXPORTING iv_item = lv_item iv_mov = c_mov-baixar iv_qtde = 5
                IMPORTING ev_falhou = DATA(lv_falhou) ).

    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = 'Baixa da quantidade reservada deve passar' ).
    DATA(ls_item) = ler_item( lv_item ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeEstoque exp = 15 msg = 'Baixa reduz o estoque físico' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeReservada exp = 0 msg = 'Baixa consome a reserva' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeDisponivel exp = 15 msg = 'Disponível não muda na baixa' ).
  ENDMETHOD.

  METHOD baixa_sem_reserva.
    DATA(lv_item) = semear_item( 20 ).

    movimentar( EXPORTING iv_item = lv_item iv_mov = c_mov-baixar iv_qtde = 1
                IMPORTING ev_falhou = DATA(lv_falhou) et_numeros = DATA(lt_numeros) ).

    cl_abap_unit_assert=>assert_true( act = lv_falhou msg = 'Baixa sem reserva deve falhar' ).
    cl_abap_unit_assert=>assert_table_contains( line = `038` table = lt_numeros msg = 'Mensagem 038 (reserva inconsistente)' ).
    cl_abap_unit_assert=>assert_equals( act = ler_item( lv_item )-QtdeEstoque exp = 20 msg = 'Estoque não muda' ).
  ENDMETHOD.

ENDCLASS.


*"* Rascunho de item novo: valores iniciais, status de estoque e validations do Save.
"! Determinations da criação e validations do Save do item.
CLASS ltcl_item_validacoes DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_item
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Cria os doubles da classe.
    CLASS-METHODS class_setup.
    "! Destrói os doubles da classe.
    CLASS-METHODS class_teardown.
    "! Doubles limpos antes de cada teste.
    METHODS setup.

    "! Item novo: moeda padrão, ativo e sem reserva.
    METHODS valores_iniciais             FOR TESTING.
    "! StatusEstoque acompanha a quantidade em estoque.
    METHODS status_acompanha_estoque     FOR TESTING.
    "! Rascunho válido passa no Prepare sem erros.
    METHODS item_valido_sem_erros        FOR TESTING.
    "! Categoria fora da CodeList é recusada (041).
    METHODS categoria_fora_da_codelist   FOR TESTING.
    "! Preço negativo é recusado (029).
    METHODS preco_negativo               FOR TESTING.
    "! Estoque negativo é recusado (030).
    METHODS estoque_negativo             FOR TESTING.
    "! Foto em formato não suportado é recusada (009).
    METHODS foto_formato_invalido        FOR TESTING.
ENDCLASS.


CLASS ltcl_item_validacoes IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    limpar_ambiente( ).
  ENDMETHOD.

  METHOD valores_iniciais.
    DATA(ls_item) = ler_item( iv_item = criar_rascunho( iv_estoque = 5 ) iv_rascunho = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = ls_item-Currency exp = zif_pc_constants=>c_moeda_padrao
                                        msg = 'Sem moeda informada, assume BRL' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-ItemAtivo exp = abap_true msg = 'Item novo nasce ativo' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeReservada exp = 0 msg = 'Item novo sem reserva' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeDisponivel exp = 5 msg = 'Disponível = estoque inicial' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-StatusEstoque exp = zif_pc_constants=>c_status_estoque-acabando
                                        msg = 'Disponível 5 => ACABANDO' ).
  ENDMETHOD.

  METHOD status_acompanha_estoque.
    DATA(lv_item) = criar_rascunho( iv_estoque = 50 ).
    cl_abap_unit_assert=>assert_equals( act = ler_item( iv_item = lv_item iv_rascunho = abap_true )-StatusEstoque
                                        exp = zif_pc_constants=>c_status_estoque-em_estoque
                                        msg = 'Disponível 50 => EM_ESTOQUE' ).

    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        UPDATE FIELDS ( QtdeEstoque )
        WITH VALUE #( ( %tky = VALUE #( ItemUUID = lv_item %is_draft = if_abap_behv=>mk-on ) QtdeEstoque = 0 ) )
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao alterar o estoque no rascunho' ).

    DATA(ls_item) = ler_item( iv_item = lv_item iv_rascunho = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-QtdeDisponivel exp = 0 msg = 'Disponível recalculado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-StatusEstoque exp = zif_pc_constants=>c_status_estoque-sem_estoque
                                        msg = 'Estoque zerado => SEM_ESTOQUE' ).
  ENDMETHOD.

  METHOD item_valido_sem_erros.
    preparar( EXPORTING iv_item = criar_rascunho( ) IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_initial( act = ls_failed-item msg = 'Item com dados válidos não deve ser bloqueado' ).
  ENDMETHOD.

  METHOD categoria_fora_da_codelist.
    preparar( EXPORTING iv_item = criar_rascunho( iv_categoria = 'XPTO' )
              IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-item msg = 'Categoria fora da CodeList deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-item )
                                             msg = 'Mensagem 041 (valor inválido)' ).
  ENDMETHOD.

  METHOD preco_negativo.
    preparar( EXPORTING iv_item = criar_rascunho( iv_preco = '-1.00' )
              IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-item msg = 'Preço negativo deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-item )
                                             msg = 'Mensagem 029 (preço inválido)' ).
  ENDMETHOD.

  METHOD estoque_negativo.
    preparar( EXPORTING iv_item = criar_rascunho( iv_estoque = -1 )
              IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-item msg = 'Estoque negativo deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-item )
                                             msg = 'Mensagem 030 (quantidade em estoque inválida)' ).
  ENDMETHOD.

  METHOD foto_formato_invalido.
    DATA(lv_item) = criar_rascunho( ).
    " Bytes de JPEG declarados como PNG: a assinatura binária precisa bater com o MIME
    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        UPDATE FIELDS ( FotoItem FotoMimeType FotoFileName )
        WITH VALUE #( ( %tky         = VALUE #( ItemUUID = lv_item %is_draft = if_abap_behv=>mk-on )
                        FotoItem     = CONV xstring( `FFD8FFE000104A46494600010100` )
                        FotoMimeType = 'image/png'
                        FotoFileName = 'item.png' ) )
      FAILED DATA(ls_failed_upd).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_upd msg = 'Falha ao anexar a foto no rascunho' ).

    preparar( EXPORTING iv_item = lv_item IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-item msg = 'Foto falsificada deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-item )
                                             msg = 'Mensagem 009 (formato de foto inválido)' ).
  ENDMETHOD.

ENDCLASS.


*"* Inativação (Edit + ItemAtivo = falso + Save): só sem saldo disponível e
*"* sem pedido em andamento com o item.
"! Inativação do item: bloqueada com estoque disponível ou pedido em andamento,
"! já no precheck do UPDATE e também no save.
CLASS ltcl_item_inativacao DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_item
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Cria os doubles da classe.
    CLASS-METHODS class_setup.
    "! Destrói os doubles da classe.
    CLASS-METHODS class_teardown.
    "! Doubles limpos antes de cada teste.
    METHODS setup.
    "! Edita o item ativo e marca como inativo. Se o precheck do update recusar,
    "! devolve essa falha (ev_no_update = abap_true); senão executa o Prepare.
    METHODS inativar
      IMPORTING iv_item      TYPE sysuuid_x16
      EXPORTING es_failed    TYPE ty_failed
                es_reported  TYPE ty_reported
                ev_no_update TYPE abap_boolean.

    "! Item com estoque disponível não pode ser inativado (014).
    METHODS bloqueia_com_saldo_disponivel  FOR TESTING.
    "! Sem saldo e sem pedido, a inativação é permitida.
    METHODS permite_sem_saldo_e_sem_pedido FOR TESTING.
    "! Item em pedido ABERTO não pode ser inativado (014).
    METHODS bloqueia_com_pedido_aberto     FOR TESTING.
    "! Pedido encerrado (FINALIZADO) não impede a inativação.
    METHODS permite_com_pedido_finalizado  FOR TESTING.
    "! A inativação bloqueada é recusada já no UPDATE (precheck), sem esperar o save.
    METHODS precheck_barra_no_update       FOR TESTING.
    "! Reativar (ItemAtivo = true) não passa pela regra de bloqueio.
    METHODS precheck_permite_reativar      FOR TESTING.
ENDCLASS.


CLASS ltcl_item_inativacao IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    limpar_ambiente( ).
  ENDMETHOD.

  METHOD inativar.
    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        EXECUTE Edit FROM VALUE #( ( %cid = 'ED' %key-ItemUUID = iv_item ) )
      FAILED DATA(ls_failed_ed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_ed msg = 'Edit do item falhou' ).

    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        UPDATE FIELDS ( ItemAtivo )
        WITH VALUE #( ( %tky = VALUE #( ItemUUID = iv_item %is_draft = if_abap_behv=>mk-on ) ItemAtivo = abap_false ) )
      FAILED DATA(ls_failed_upd)
      REPORTED DATA(ls_reported_upd).

    " Precheck do update recusou: a regra já foi aplicada, não há o que salvar
    IF ls_failed_upd IS NOT INITIAL.
      es_failed    = CORRESPONDING #( DEEP ls_failed_upd ).
      es_reported  = CORRESPONDING #( DEEP ls_reported_upd ).
      ev_no_update = abap_true.
      RETURN.
    ENDIF.

    preparar( EXPORTING iv_item = iv_item IMPORTING es_failed = es_failed es_reported = es_reported ).
  ENDMETHOD.

  METHOD precheck_barra_no_update.
    inativar( EXPORTING iv_item = semear_item( 5 ) IMPORTING es_reported  = DATA(ls_reported)
                                                             ev_no_update = DATA(lv_no_update) ).

    cl_abap_unit_assert=>assert_true( act = lv_no_update
                                      msg = 'Inativação bloqueada deve ser recusada no precheck do UPDATE' ).
    DATA(lt_numeros) = lcl_msgs=>numeros( ls_reported-item ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_numeros[ table_line = '014' ] ) )
                                      msg = 'Precheck deve devolver a mensagem 014' ).
  ENDMETHOD.

  METHOD precheck_permite_reativar.
    DATA(lv_item) = semear_item( iv_estoque = 5 iv_ativo = abap_false ).

    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        EXECUTE Edit FROM VALUE #( ( %cid = 'ED' %key-ItemUUID = lv_item ) )
      FAILED DATA(ls_failed_ed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_ed msg = 'Edit do item falhou' ).

    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        UPDATE FIELDS ( ItemAtivo )
        WITH VALUE #( ( %tky = VALUE #( ItemUUID = lv_item %is_draft = if_abap_behv=>mk-on ) ItemAtivo = abap_true ) )
      FAILED DATA(ls_failed_upd).

    cl_abap_unit_assert=>assert_initial( act = ls_failed_upd msg = 'Reativar item não é bloqueado pelo precheck' ).
  ENDMETHOD.

  METHOD bloqueia_com_saldo_disponivel.
    inativar( EXPORTING iv_item = semear_item( 5 ) IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-item msg = 'Item com saldo disponível não pode ser inativado' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-item )
                                             msg = 'Mensagem 014 (inativação bloqueada)' ).
  ENDMETHOD.

  METHOD permite_sem_saldo_e_sem_pedido.
    inativar( EXPORTING iv_item = semear_item( 0 ) IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_initial( act = ls_failed-item msg = 'Item sem saldo e sem pedido pode ser inativado' ).
  ENDMETHOD.

  METHOD bloqueia_com_pedido_aberto.
    DATA(lv_item) = semear_item( 0 ).
    semear_pedido_com_item( lv_item ).

    inativar( EXPORTING iv_item = lv_item IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-item msg = 'Item em pedido ABERTO não pode ser inativado' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-item )
                                             msg = 'Mensagem 014 (inativação bloqueada)' ).
  ENDMETHOD.

  METHOD permite_com_pedido_finalizado.
    DATA(lv_item) = semear_item( 0 ).
    semear_pedido_com_item( iv_item = lv_item iv_status = zif_pc_constants=>c_status_pedido-finalizado ).

    inativar( EXPORTING iv_item = lv_item IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_initial( act = ls_failed-item msg = 'Pedido encerrado não impede a inativação' ).
  ENDMETHOD.

ENDCLASS.


*"* Exclusão: bloqueada para item com reserva ou ligado a pedido (ativo ou rascunho).
"! Exclusão do item: bloqueada com reserva ou vínculo com pedido (feature
"! control de delete + precheck).
CLASS ltcl_item_exclusao DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_item
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Cria os doubles da classe.
    CLASS-METHODS class_setup.
    "! Destrói os doubles da classe.
    CLASS-METHODS class_teardown.
    "! Doubles limpos antes de cada teste.
    METHODS setup.
    "! Exclui o item ativo; devolve abap_true se a exclusão foi recusada.
    METHODS excluir
      IMPORTING iv_item          TYPE sysuuid_x16
      RETURNING VALUE(rv_falhou) TYPE abap_boolean.

    "! Item sem reserva e sem pedido pode ser excluído.
    METHODS exclui_item_livre             FOR TESTING.
    "! Item com reserva não pode ser excluído (031).
    METHODS bloqueia_com_reserva          FOR TESTING.
    "! Item em pedido gravado não pode ser excluído (031).
    METHODS bloqueia_em_pedido            FOR TESTING.
    "! Item em pedido ainda em rascunho também não pode ser excluído (031).
    METHODS bloqueia_em_pedido_rascunho   FOR TESTING.
ENDCLASS.


CLASS ltcl_item_exclusao IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    limpar_ambiente( ).
  ENDMETHOD.

  METHOD excluir.
    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        DELETE FROM VALUE #( ( %key-ItemUUID = iv_item %is_draft = if_abap_behv=>mk-off ) )
      FAILED DATA(ls_failed).
    rv_falhou = xsdbool( ls_failed-item IS NOT INITIAL ).
  ENDMETHOD.

  METHOD exclui_item_livre.
    cl_abap_unit_assert=>assert_false( act = excluir( semear_item( 10 ) )
                                       msg = 'Item sem reserva e sem pedido pode ser excluído' ).
  ENDMETHOD.

  METHOD bloqueia_com_reserva.
    cl_abap_unit_assert=>assert_true( act = excluir( semear_item( iv_estoque = 10 iv_reservada = 2 ) )
                                      msg = 'Item com reserva não pode ser excluído' ).
  ENDMETHOD.

  METHOD bloqueia_em_pedido.
    DATA(lv_item) = semear_item( 10 ).
    semear_pedido_com_item( iv_item = lv_item iv_status = zif_pc_constants=>c_status_pedido-cancelado ).

    cl_abap_unit_assert=>assert_true( act = excluir( lv_item )
                                      msg = 'Item usado em qualquer pedido (mesmo encerrado) não pode ser excluído' ).
  ENDMETHOD.

  METHOD bloqueia_em_pedido_rascunho.
    DATA(lv_item) = semear_item( 10 ).
    semear_item_pedido_rascunho( lv_item ).

    cl_abap_unit_assert=>assert_true( act = excluir( lv_item )
                                      msg = 'Item em pedido ainda em rascunho não pode ser excluído' ).
  ENDMETHOD.

ENDCLASS.
