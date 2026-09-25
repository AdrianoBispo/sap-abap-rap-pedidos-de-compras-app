*"* Local Types da behavior pool ZBP_R_PC_ITEM

CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_area,
        item       TYPE string VALUE `VALIDAR_ITEM`,
        quantidade TYPE string VALUE `VALIDAR_QUANTIDADES`,
        inativacao TYPE string VALUE `VALIDAR_INATIVACAO`,
        sku        TYPE string VALUE `VALIDAR_SKU`,
        foto       TYPE string VALUE `VALIDAR_FOTO`,
      END OF c_area.

    CONSTANTS:
      BEGIN OF c_movimento,
        reservar TYPE c LENGTH 1 VALUE 'R',
        liberar  TYPE c LENGTH 1 VALUE 'L',
        baixar   TYPE c LENGTH 1 VALUE 'B',
      END OF c_movimento.

    TYPES:
      BEGIN OF ty_movimento,
        is_draft  TYPE abp_behv_flag,
        item_uuid TYPE sysuuid_x16,
        qtde      TYPE i,
        ok        TYPE abap_boolean,
      END OF ty_movimento,
      tt_movimento TYPE STANDARD TABLE OF ty_movimento WITH EMPTY KEY.

    TYPES tt_uuid TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item RESULT result.

    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Item.

    METHODS ReservarEstoque FOR MODIFY
      IMPORTING keys FOR ACTION Item~ReservarEstoque RESULT result.

    METHODS LiberarReserva FOR MODIFY
      IMPORTING keys FOR ACTION Item~LiberarReserva RESULT result.

    METHODS BaixarEstoque FOR MODIFY
      IMPORTING keys FOR ACTION Item~BaixarEstoque RESULT result.

    METHODS DefinirValoresIniciais FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~DefinirValoresIniciais.

    METHODS RecalcularStatusEstoque FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~RecalcularStatusEstoque.

    METHODS GerarSku FOR DETERMINE ON SAVE
      IMPORTING keys FOR Item~GerarSku.

    METHODS ValidarItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarItem.

    METHODS ValidarQuantidades FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarQuantidades.

    METHODS ValidarInativacaoItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarInativacaoItem.

    METHODS ValidarSkuUnico FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarSkuUnico.

    METHODS ValidarFoto FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarFoto.

    "! Reserva / libera / baixa estoque. Relê o item (já bloqueado pelo
    "! framework antes da action) e valida as quantidades atuais.
    METHODS movimentar
      IMPORTING iv_tipo      TYPE c
      CHANGING  ct_movimento TYPE tt_movimento
                cs_failed    TYPE RESPONSE FOR FAILED EARLY zr_pc_item
                cs_reported  TYPE RESPONSE FOR REPORTED EARLY zr_pc_item.

    "! Itens vinculados a qualquer pedido (ativo ou draft).
    METHODS itens_em_pedidos
      IMPORTING it_itens        TYPE tt_uuid
      RETURNING VALUE(rt_itens) TYPE tt_uuid.

    "! Itens vinculados a pedidos ainda não encerrados.
    METHODS itens_em_pedidos_ativos
      IMPORTING it_itens        TYPE tt_uuid
      RETURNING VALUE(rt_itens) TYPE tt_uuid.
ENDCLASS.


CLASS lhc_item IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Cada operação verifica sua própria atividade (ACTVT)
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = COND #( WHEN zcl_pc_auth=>admin_pode_criar( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = COND #( WHEN zcl_pc_auth=>admin_pode_alterar( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = COND #( WHEN zcl_pc_auth=>admin_pode_excluir( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-Edit = if_abap_behv=>mk-on.
      result-%action-Edit = COND #( WHEN zcl_pc_auth=>admin_pode_alterar( ) = abap_true
                                    THEN if_abap_behv=>auth-allowed
                                    ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    DATA lt_ids TYPE tt_uuid.

    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( QtdeReservada )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT lt_itens INTO DATA(ls_i).
      INSERT ls_i-ItemUUID INTO TABLE lt_ids.
    ENDLOOP.
    DATA(lt_vinculados) = itens_em_pedidos( lt_ids ).

    result = VALUE #( FOR i IN lt_itens
                      ( %tky    = i-%tky
                        %delete = COND #( WHEN i-QtdeReservada > 0
                                            OR line_exists( lt_vinculados[ table_line = i-ItemUUID ] )
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.


  METHOD precheck_delete.
    DATA lt_ids TYPE tt_uuid.

    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( QtdeReservada )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT lt_itens INTO DATA(ls_i).
      INSERT ls_i-ItemUUID INTO TABLE lt_ids.
    ENDLOOP.
    DATA(lt_vinculados) = itens_em_pedidos( lt_ids ).

    LOOP AT lt_itens INTO DATA(ls_item).
      IF ls_item-QtdeReservada > 0 OR line_exists( lt_vinculados[ table_line = ls_item-ItemUUID ] ).
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>item_exclusao_bloqueada ) ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD itens_em_pedidos.
    CHECK it_itens IS NOT INITIAL.

    SELECT item_uuid
      FROM zta_pc_item_ped
      FOR ALL ENTRIES IN @it_itens
      WHERE item_uuid = @it_itens-table_line
      INTO TABLE @DATA(lt_ativos).

    SELECT itemuuid
      FROM zta_pc_itped_d
      FOR ALL ENTRIES IN @it_itens
      WHERE itemuuid = @it_itens-table_line
      INTO TABLE @DATA(lt_drafts).

    LOOP AT lt_ativos INTO DATA(ls_a).
      INSERT ls_a-item_uuid INTO TABLE rt_itens.
    ENDLOOP.
    LOOP AT lt_drafts INTO DATA(ls_d).
      INSERT ls_d-itemuuid INTO TABLE rt_itens.
    ENDLOOP.
  ENDMETHOD.


  METHOD itens_em_pedidos_ativos.
    CHECK it_itens IS NOT INITIAL.

    SELECT ip~item_uuid
      FROM zta_pc_item_ped AS ip
      INNER JOIN zta_pc_pedido AS p ON p~pedido_uuid = ip~pedido_uuid
      FOR ALL ENTRIES IN @it_itens
      WHERE ip~item_uuid = @it_itens-table_line
        AND p~status_pedido IN ( @zif_pc_constants=>c_status_pedido-criado,
                                 @zif_pc_constants=>c_status_pedido-aguardando_pagamento,
                                 @zif_pc_constants=>c_status_pedido-aguardando_aprovacao )
      INTO TABLE @DATA(lt_ativos).

    " Pedidos em draft (ainda não ativados) também contam como ativos
    SELECT itemuuid
      FROM zta_pc_itped_d
      FOR ALL ENTRIES IN @it_itens
      WHERE itemuuid = @it_itens-table_line
      INTO TABLE @DATA(lt_drafts).

    LOOP AT lt_ativos INTO DATA(ls_a).
      INSERT ls_a-item_uuid INTO TABLE rt_itens.
    ENDLOOP.
    LOOP AT lt_drafts INTO DATA(ls_d).
      INSERT ls_d-itemuuid INTO TABLE rt_itens.
    ENDLOOP.
  ENDMETHOD.


  METHOD ReservarEstoque.
    DATA(lt_mov) = VALUE tt_movimento( FOR k IN keys ( is_draft  = k-%is_draft
                                                       item_uuid = k-ItemUUID
                                                       qtde      = k-%param-Quantidade ) ).

    movimentar( EXPORTING iv_tipo      = c_movimento-reservar
                CHANGING  ct_movimento = lt_mov
                          cs_failed    = failed
                          cs_reported  = reported ).

    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    " Resultado somente para os itens movimentados com sucesso
    LOOP AT lt_itens INTO DATA(ls_item).
      IF line_exists( lt_mov[ is_draft = ls_item-%is_draft item_uuid = ls_item-ItemUUID ok = abap_true ] ).
        APPEND VALUE #( %tky = ls_item-%tky %param = ls_item ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD LiberarReserva.
    DATA(lt_mov) = VALUE tt_movimento( FOR k IN keys ( is_draft  = k-%is_draft
                                                       item_uuid = k-ItemUUID
                                                       qtde      = k-%param-Quantidade ) ).

    movimentar( EXPORTING iv_tipo      = c_movimento-liberar
                CHANGING  ct_movimento = lt_mov
                          cs_failed    = failed
                          cs_reported  = reported ).

    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    " Resultado somente para os itens movimentados com sucesso
    LOOP AT lt_itens INTO DATA(ls_item).
      IF line_exists( lt_mov[ is_draft = ls_item-%is_draft item_uuid = ls_item-ItemUUID ok = abap_true ] ).
        APPEND VALUE #( %tky = ls_item-%tky %param = ls_item ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD BaixarEstoque.
    DATA(lt_mov) = VALUE tt_movimento( FOR k IN keys ( is_draft  = k-%is_draft
                                                       item_uuid = k-ItemUUID
                                                       qtde      = k-%param-Quantidade ) ).

    movimentar( EXPORTING iv_tipo      = c_movimento-baixar
                CHANGING  ct_movimento = lt_mov
                          cs_failed    = failed
                          cs_reported  = reported ).

    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    " Resultado somente para os itens movimentados com sucesso
    LOOP AT lt_itens INTO DATA(ls_item).
      IF line_exists( lt_mov[ is_draft = ls_item-%is_draft item_uuid = ls_item-ItemUUID ok = abap_true ] ).
        APPEND VALUE #( %tky = ls_item-%tky %param = ls_item ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD movimentar.
    TYPES:
      BEGIN OF ty_saldo,
        is_draft      TYPE abp_behv_flag,
        item_uuid     TYPE sysuuid_x16,
        sku           TYPE zr_pc_item-Sku,
        ativo         TYPE abap_boolean,
        estoque       TYPE i,
        reservada     TYPE i,
        alterado      TYPE abap_boolean,
      END OF ty_saldo.
    DATA lt_saldo  TYPE SORTED TABLE OF ty_saldo WITH UNIQUE KEY is_draft item_uuid.
    DATA lt_chaves TYPE TABLE FOR READ IMPORT zr_pc_item\\Item.
    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_item\\Item.

    " 1) Releitura do item dentro da LUW. O framework já obteve o lock
    "    exclusivo do item antes de executar a action; portanto, o saldo
    "    lido aqui não pode ser alterado por outra transação até o COMMIT.
    LOOP AT ct_movimento INTO DATA(ls_mov).
      IF NOT line_exists( lt_chaves[ %is_draft = ls_mov-is_draft ItemUUID = ls_mov-item_uuid ] ).
        APPEND VALUE #( %is_draft = ls_mov-is_draft ItemUUID = ls_mov-item_uuid ) TO lt_chaves.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( Sku ItemAtivo QtdeEstoque QtdeReservada )
        WITH lt_chaves
      RESULT DATA(lt_itens).

    LOOP AT lt_itens INTO DATA(ls_item).
      INSERT VALUE #( is_draft  = ls_item-%is_draft
                      item_uuid = ls_item-ItemUUID
                      sku       = ls_item-Sku
                      ativo     = ls_item-ItemAtivo
                      estoque   = ls_item-QtdeEstoque
                      reservada = ls_item-QtdeReservada ) INTO TABLE lt_saldo.
    ENDLOOP.

    " 2) Aplica os movimentos em sequência (o mesmo item pode aparecer
    "    mais de uma vez quando a action do pedido é executada em massa)
    LOOP AT ct_movimento ASSIGNING FIELD-SYMBOL(<ls_mov>).
      DATA lo_msg TYPE REF TO zcx_pc_msg.
      CLEAR lo_msg.

      READ TABLE lt_saldo ASSIGNING FIELD-SYMBOL(<ls_saldo>)
           WITH TABLE KEY is_draft = <ls_mov>-is_draft item_uuid = <ls_mov>-item_uuid.
      IF sy-subrc <> 0.
        lo_msg = NEW #( textid = zif_pc_errors_constants=>item_estoque_concorrente attr1 = '?' ).
      ELSEIF <ls_mov>-qtde <= 0.
        lo_msg = NEW #( textid = zif_pc_errors_constants=>item_qtde_invalida ).
      ELSE.
        CASE iv_tipo.
          WHEN c_movimento-reservar.
            IF <ls_saldo>-ativo = abap_false.
              lo_msg = NEW #( textid = zif_pc_errors_constants=>item_inativo attr1 = <ls_saldo>-sku ).
            ELSEIF <ls_mov>-qtde > <ls_saldo>-estoque - <ls_saldo>-reservada.
              lo_msg = NEW #( textid = zif_pc_errors_constants=>item_estoque_insuficiente
                              attr1  = <ls_saldo>-sku
                              attr2  = |{ <ls_saldo>-estoque - <ls_saldo>-reservada }| ).
            ELSE.
              <ls_saldo>-reservada += <ls_mov>-qtde.
            ENDIF.

          WHEN c_movimento-liberar.
            IF <ls_mov>-qtde > <ls_saldo>-reservada.
              lo_msg = NEW #( textid = zif_pc_errors_constants=>item_reserva_inconsistente attr1 = <ls_saldo>-sku ).
            ELSE.
              <ls_saldo>-reservada -= <ls_mov>-qtde.
            ENDIF.

          WHEN c_movimento-baixar.
            IF <ls_mov>-qtde > <ls_saldo>-reservada OR <ls_mov>-qtde > <ls_saldo>-estoque.
              lo_msg = NEW #( textid = zif_pc_errors_constants=>item_reserva_inconsistente attr1 = <ls_saldo>-sku ).
            ELSE.
              <ls_saldo>-estoque   -= <ls_mov>-qtde.
              <ls_saldo>-reservada -= <ls_mov>-qtde.
            ENDIF.
        ENDCASE.
      ENDIF.

      IF lo_msg IS BOUND.
        <ls_mov>-ok = abap_false.
        APPEND VALUE #( %tky-%is_draft = <ls_mov>-is_draft
                        %tky-ItemUUID  = <ls_mov>-item_uuid
                        %fail-cause    = if_abap_behv=>cause-unspecific ) TO cs_failed-item.
        APPEND VALUE #( %tky-%is_draft = <ls_mov>-is_draft
                        %tky-ItemUUID  = <ls_mov>-item_uuid
                        %msg           = lo_msg ) TO cs_reported-item.
      ELSE.
        <ls_mov>-ok = abap_true.
        <ls_saldo>-alterado = abap_true.
      ENDIF.
    ENDLOOP.

    " 3) Persiste os novos saldos + disponibilidade + status
    LOOP AT lt_saldo INTO DATA(ls_saldo) WHERE alterado = abap_true.
      DATA(lv_disponivel) = ls_saldo-estoque - ls_saldo-reservada.
      APPEND VALUE #( %tky-%is_draft = ls_saldo-is_draft
                      %tky-ItemUUID  = ls_saldo-item_uuid
                      QtdeEstoque    = ls_saldo-estoque
                      QtdeReservada  = ls_saldo-reservada
                      QtdeDisponivel = lv_disponivel
                      StatusEstoque  = zcl_pc_util=>calcular_status_estoque( lv_disponivel )
                      %control = VALUE #( QtdeEstoque    = if_abap_behv=>mk-on
                                          QtdeReservada  = if_abap_behv=>mk-on
                                          QtdeDisponivel = if_abap_behv=>mk-on
                                          StatusEstoque  = if_abap_behv=>mk-on ) ) TO lt_update.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item UPDATE FROM lt_update
      FAILED DATA(ls_failed_mov)
      REPORTED DATA(ls_reported_mov).

    LOOP AT ls_reported_mov-item INTO DATA(ls_rep_mov) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_mov ) TO cs_reported-item.
    ENDLOOP.
    IF ls_failed_mov-item IS NOT INITIAL.
      APPEND LINES OF ls_failed_mov-item TO cs_failed-item.
    ENDIF.
  ENDMETHOD.


  METHOD DefinirValoresIniciais.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( Currency ItemAtivo QtdeEstoque )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    MODIFY ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( Currency ItemAtivo QtdeReservada QtdeDisponivel StatusEstoque )
        WITH VALUE #( FOR i IN lt_itens
                      ( %tky           = i-%tky
                        Currency       = COND #( WHEN i-Currency IS INITIAL
                                                 THEN zif_pc_constants=>c_moeda_padrao
                                                 ELSE i-Currency )
                        ItemAtivo      = abap_true
                        QtdeReservada  = 0
                        QtdeDisponivel = i-QtdeEstoque
                        StatusEstoque  = zcl_pc_util=>calcular_status_estoque( i-QtdeEstoque ) ) )
      REPORTED DATA(ls_rep_item0_all).

    LOOP AT ls_rep_item0_all-item INTO DATA(ls_rep_item0) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_item0 ) TO reported-item.
    ENDLOOP.
  ENDMETHOD.


  METHOD RecalcularStatusEstoque.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( QtdeEstoque QtdeReservada QtdeDisponivel StatusEstoque )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_item\\Item.

    LOOP AT lt_itens INTO DATA(ls_item).
      DATA(lv_disponivel) = ls_item-QtdeEstoque - ls_item-QtdeReservada.
      DATA(lv_status)     = zcl_pc_util=>calcular_status_estoque( lv_disponivel ).
      IF lv_disponivel <> ls_item-QtdeDisponivel OR lv_status <> ls_item-StatusEstoque.
        APPEND VALUE #( %tky           = ls_item-%tky
                        QtdeDisponivel = lv_disponivel
                        StatusEstoque  = lv_status
                        %control = VALUE #( QtdeDisponivel = if_abap_behv=>mk-on
                                            StatusEstoque  = if_abap_behv=>mk-on ) ) TO lt_update.
      ENDIF.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item UPDATE FROM lt_update
      REPORTED DATA(ls_reported_stat).

    LOOP AT ls_reported_stat-item INTO DATA(ls_rep_stat) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_stat ) TO reported-item.
    ENDLOOP.
  ENDMETHOD.


  METHOD GerarSku.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( Sku Categoria )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    DELETE lt_itens WHERE Sku IS NOT INITIAL.
    CHECK lt_itens IS NOT INITIAL.

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_item\\Item.

    LOOP AT lt_itens INTO DATA(ls_item).
      TRY.
          APPEND VALUE #( %tky         = ls_item-%tky
                          Sku          = zcl_pc_numeracao=>gerar_sku( ls_item-Categoria )
                          %control-Sku = if_abap_behv=>mk-on ) TO lt_update.
        CATCH cx_number_ranges INTO DATA(lx_nr).
          APPEND VALUE #( %tky = ls_item-%tky
                          %msg = NEW zcx_pc_msg( textid   = zif_pc_errors_constants=>numeracao_erro
                                                 attr1    = lx_nr->get_text( )
                                                 previous = lx_nr ) ) TO reported-item.
      ENDTRY.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item UPDATE FROM lt_update
      REPORTED DATA(ls_reported_sku).

    LOOP AT ls_reported_sku-item INTO DATA(ls_rep_sku) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_sku ) TO reported-item.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarItem.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( Nome Categoria PrecoUnitario Currency Peso Altura Largura Profundidade )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT lt_itens INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item ) TO reported-item.

      IF ls_item-Nome IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>campo_obrigatorio attr1 = 'Nome' )
                        %element-Nome = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.

      IF ls_item-Categoria IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>campo_obrigatorio attr1 = 'Categoria' )
                        %element-Categoria = if_abap_behv=>mk-on ) TO reported-item.
      ELSE.
        SELECT SINGLE @abap_true
          FROM zr_pc_codelist
          WHERE Lista  = @zif_pc_constants=>c_codelist-categoria
            AND Codigo = @ls_item-Categoria
          INTO @DATA(lv_categoria_ok).
        IF lv_categoria_ok = abap_false.
          APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
          APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                          %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>valor_invalido attr1 = 'Categoria' )
                          %element-Categoria = if_abap_behv=>mk-on ) TO reported-item.
        ENDIF.
        CLEAR lv_categoria_ok.
      ENDIF.

      IF ls_item-PrecoUnitario < 0.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>item_preco_invalido )
                        %element-PrecoUnitario = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.

      IF ls_item-Currency IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>campo_obrigatorio attr1 = 'Moeda' )
                        %element-Currency = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.

      IF ls_item-Peso < 0 OR ls_item-Altura < 0 OR ls_item-Largura < 0 OR ls_item-Profundidade < 0.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>item_dimensao_invalida ) ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarQuantidades.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( QtdeEstoque QtdeReservada )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT lt_itens INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-quantidade ) TO reported-item.

      " QtdeEstoque >= 0 e QtdeReservada <= QtdeEstoque
      IF ls_item-QtdeEstoque < 0 OR ls_item-QtdeEstoque < ls_item-QtdeReservada.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-quantidade
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>item_qtde_estoque_invalida
                                               attr1  = |{ ls_item-QtdeReservada }| )
                        %element-QtdeEstoque = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarInativacaoItem.
    DATA lt_ids TYPE tt_uuid.

    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( ItemAtivo QtdeEstoque QtdeReservada )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT lt_itens INTO DATA(ls_i) WHERE ItemAtivo = abap_false.
      INSERT ls_i-ItemUUID INTO TABLE lt_ids.
    ENDLOOP.
    DATA(lt_em_pedido_ativo) = itens_em_pedidos_ativos( lt_ids ).

    LOOP AT lt_itens INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-inativacao ) TO reported-item.

      CHECK ls_item-ItemAtivo = abap_false.

      " Regra: não inativar item com estoque disponível ou pedido ativo vinculado
      IF ls_item-QtdeEstoque - ls_item-QtdeReservada > 0
         OR line_exists( lt_em_pedido_ativo[ table_line = ls_item-ItemUUID ] ).
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-inativacao
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>item_inativacao_bloqueada )
                        %element-ItemAtivo = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarSkuUnico.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( Sku )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT lt_itens INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-sku ) TO reported-item.

      " Em draft o SKU ainda não existe (gerado na ativação)
      IF ls_item-%is_draft = if_abap_behv=>mk-on.
        CONTINUE.
      ENDIF.

      IF ls_item-Sku IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-sku
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>campo_obrigatorio attr1 = 'SKU' ) ) TO reported-item.
        CONTINUE.
      ENDIF.

      SELECT SINGLE @abap_true
        FROM zta_pc_item
        WHERE sku       =  @ls_item-Sku
          AND item_uuid <> @ls_item-ItemUUID
        INTO @DATA(lv_duplicado).

      IF lv_duplicado = abap_true.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-sku
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>item_sku_duplicado )
                        %element-Sku = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
      CLEAR lv_duplicado.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarFoto.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( FotoItem FotoMimeType FotoFileName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT lt_itens INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-foto ) TO reported-item.

      IF zcl_pc_util=>validar_imagem( iv_conteudo     = ls_item-FotoItem
                                      iv_mime_type    = ls_item-FotoMimeType
                                      iv_nome_arquivo = ls_item-FotoFileName ) = abap_false.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-foto
                        %msg = NEW zcx_pc_msg( textid = zif_pc_errors_constants=>foto_formato_invalido )
                        %element-FotoItem = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
