*"* Local Types da behavior pool ZBP_R_PC_ITEM

"! <h1>Handler da entidade Item (BO {@link ZR_PC_ITEM})</h1>
"! Regras do item de estoque: autorização, feature control, prechecks
"! (exclusão e inativação), movimentação de estoque chamada pelo BO Pedido,
"! determinations, validations e importação por planilha.
CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      "! State areas das validations (mensagens de estado no rascunho)
      BEGIN OF c_area,
        "! {@link .METH:ValidarItem}
        item       TYPE string VALUE `VALIDAR_ITEM`,
        "! {@link .METH:ValidarQuantidades}
        quantidade TYPE string VALUE `VALIDAR_QUANTIDADES`,
        "! {@link .METH:ValidarInativacaoItem}
        inativacao TYPE string VALUE `VALIDAR_INATIVACAO`,
        "! {@link .METH:ValidarSkuUnico}
        sku        TYPE string VALUE `VALIDAR_SKU`,
        "! {@link .METH:ValidarFoto}
        foto       TYPE string VALUE `VALIDAR_FOTO`,
      END OF c_area.

    CONSTANTS:
      "! Tipos de movimento de estoque de {@link .METH:movimentar}
      BEGIN OF c_movimento,
        "! Reserva (QtdeReservada aumenta)
        reservar TYPE c LENGTH 1 VALUE 'R',
        "! Liberação da reserva (QtdeReservada diminui)
        liberar  TYPE c LENGTH 1 VALUE 'L',
        "! Baixa (QtdeEstoque e QtdeReservada diminuem)
        baixar   TYPE c LENGTH 1 VALUE 'B',
      END OF c_movimento.

    TYPES:
      "! Movimento de estoque solicitado para um item
      BEGIN OF ty_movimento,
        "! Instância em rascunho ou ativa
        is_draft  TYPE abp_behv_flag,
        "! Item movimentado
        item_uuid TYPE sysuuid_x16,
        "! Quantidade do movimento
        qtde      TYPE i,
        "! Preenchido por {@link .METH:movimentar}: abap_true se o movimento foi aplicado
        ok        TYPE abap_boolean,
      END OF ty_movimento,

      "! Movimentos processados em sequência por {@link .METH:movimentar}
      tt_movimento TYPE STANDARD TABLE OF ty_movimento WITH EMPTY KEY,
      "! Conjunto de UUIDs de itens
      tt_uuid TYPE SORTED TABLE OF sysuuid_x16 WITH NON-UNIQUE KEY table_line,
      "! Range de UUIDs (consultas com IN, sem FOR ALL ENTRIES)
      tt_range_uuid TYPE RANGE OF sysuuid_x16,
      "! FAILED do BO Item
      s_failed TYPE RESPONSE FOR FAILED EARLY zr_pc_item,
      "! REPORTED do BO Item
      s_reported  TYPE RESPONSE FOR REPORTED EARLY zr_pc_item.

    TYPES:
      "! Saldo usado na regra de inativação (valor novo do request ou o atual)
      BEGIN OF ty_saldo_item,
        "! Item avaliado
        item_uuid TYPE sysuuid_x16,
        "! Quantidade em estoque
        estoque   TYPE i,
        "! Quantidade reservada
        reservada TYPE i,
      END OF ty_saldo_item,
      "! Saldos avaliados por {@link .METH:inativacao_bloqueada}
      tt_saldo_item TYPE STANDARD TABLE OF ty_saldo_item WITH EMPTY KEY.

    "! Autorização global: cada operação confere sua atividade em {@link ZCL_PC_AUTH}
    "! (somente administrador cria, altera, exclui e importa).
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item RESULT result.

    "! Importação em massa por planilha (.xlsx/.csv): cria itens ativos, com SKU
    "! gerado na hora. Tudo ou nada: qualquer erro cancela a importação.
    METHODS ImportarPlanilha FOR MODIFY
      IMPORTING keys FOR ACTION Item~ImportarPlanilha.

    "! Reporta os erros da importação (primeiro o resumo) e falha a action,
    "! o que descarta qualquer item já criado no buffer.
    METHODS falhar_importacao
      IMPORTING it_erros     TYPE string_table
                iv_cid       TYPE abp_behv_cid
      CHANGING  cs_failed    TYPE s_failed
                cs_reported  TYPE s_reported.

    "! "Linha N: " a partir do %cid (ITM seguido do número da linha).
    METHODS linha_do_cid
      IMPORTING iv_cid          TYPE csequence
      RETURNING VALUE(rv_texto) TYPE string.

    "! Feature control: exclusão desabilitada para item com reserva ou vinculado
    "! a pedido (ativo ou rascunho), ver {@link .METH:itens_em_pedidos}.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item RESULT result.

    "! Precheck da exclusão: mesma regra do feature control, para chamadas via
    "! EML/API (mensagem 031).
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Item.

    "! Precheck da inativação: recusa na hora (ao alterar ItemAtivo no rascunho
    "! ou via EML) a inativação de item com estoque disponível ou pedido em
    "! andamento. A mesma regra roda no save (ValidarInativacaoItem).
    METHODS precheck_update FOR PRECHECK
      IMPORTING entities FOR UPDATE Item.

    "! Itens (entre os informados) cuja inativação é bloqueada: estoque
    "! disponível maior que zero ou vínculo com pedido em andamento.
    METHODS inativacao_bloqueada
      IMPORTING it_saldo             TYPE tt_saldo_item
      RETURNING VALUE(rt_bloqueados) TYPE tt_uuid.

    "! Action interna (chamada pelo BO Pedido via EML): reserva a quantidade
    "! informada, ver {@link .METH:movimentar}.
    METHODS ReservarEstoque FOR MODIFY
      IMPORTING keys FOR ACTION Item~ReservarEstoque RESULT result.

    "! Action interna (chamada pelo BO Pedido via EML): libera a reserva,
    "! ver {@link .METH:movimentar}.
    METHODS LiberarReserva FOR MODIFY
      IMPORTING keys FOR ACTION Item~LiberarReserva RESULT result.

    "! Action interna (chamada pelo BO Pedido via EML na aprovação): baixa estoque
    "! e reserva, ver {@link .METH:movimentar}.
    METHODS BaixarEstoque FOR MODIFY
      IMPORTING keys FOR ACTION Item~BaixarEstoque RESULT result.

    "! Item novo: moeda padrão, ativo, sem reserva e status de estoque calculado.
    METHODS DefinirValoresIniciais FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~DefinirValoresIniciais.

    "! Recalcula QtdeDisponivel e StatusEstoque quando QtdeEstoque muda
    "! ({@link ZCL_PC_UTIL.METH:calcular_status_estoque}).
    METHODS RecalcularStatusEstoque FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~RecalcularStatusEstoque.

    "! Gera o SKU com o prefixo da categoria ({@link ZCL_PC_NUMERACAO}); gera de
    "! novo se a categoria mudou depois da primeira geração.
    METHODS GerarSku FOR DETERMINE ON SAVE
      IMPORTING keys FOR Item~GerarSku.

    "! Nome, categoria (CodeList lida uma vez), preço e moeda.
    METHODS ValidarItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarItem.

    "! QtdeEstoque não negativa e não menor que a reservada (mensagem 030).
    METHODS ValidarQuantidades FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarQuantidades.

    "! Inativação no save: mesma regra de {@link .METH:precheck_update}
    "! (ver {@link .METH:inativacao_bloqueada}, mensagem 014).
    METHODS ValidarInativacaoItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarInativacaoItem.

    "! SKU obrigatório na instância ativa e único (SKUs gravados lidos numa
    "! única consulta).
    METHODS ValidarSkuUnico FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarSkuUnico.

    "! Foto JPEG/PNG/WEBP coerente com o MIME type ({@link ZCL_PC_UTIL.METH:validar_imagem}).
    METHODS ValidarFoto FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidarFoto.

    "! Reserva / libera / baixa estoque. Relê o item (já bloqueado pelo
    "! framework antes da action) e valida as quantidades atuais.
    METHODS movimentar
      IMPORTING iv_tipo      TYPE c
      CHANGING  ct_movimento TYPE tt_movimento
                cs_failed    TYPE s_failed
                cs_reported  TYPE s_reported.

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
    IF requested_authorizations-%action-ImportarPlanilha = if_abap_behv=>mk-on.
      result-%action-ImportarPlanilha = COND #( WHEN zcl_pc_auth=>admin_pode_criar( ) = abap_true
                                                THEN if_abap_behv=>auth-allowed
                                                ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( QtdeReservada )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    DATA(lt_vinculados) = itens_em_pedidos( VALUE #( FOR i IN lt_itens ( i-ItemUUID ) ) ).

    result = VALUE #( FOR i IN lt_itens
                      ( %tky    = i-%tky
                        %delete = COND #( WHEN i-QtdeReservada > 0
                                            OR line_exists( lt_vinculados[ table_line = i-ItemUUID ] )
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.


  METHOD precheck_delete.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( QtdeReservada )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    DATA(lt_vinculados) = itens_em_pedidos( VALUE #( FOR i IN lt_itens ( i-ItemUUID ) ) ).

    LOOP AT lt_itens INTO DATA(ls_item).
      IF ls_item-QtdeReservada > 0 OR line_exists( lt_vinculados[ table_line = ls_item-ItemUUID ] ).
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>item_exclusao_bloqueada ) ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD itens_em_pedidos.
    CHECK it_itens IS NOT INITIAL.

    DATA(lt_range) = VALUE tt_range_uuid( FOR i IN it_itens ( sign = 'I' option = 'EQ' low = i ) ).

    " Pedidos gravados e rascunhos numa única consulta
    SELECT item_uuid
      FROM zta_pc_item_ped
      WHERE item_uuid IN @lt_range
    UNION DISTINCT
    SELECT itemuuid AS item_uuid
      FROM zta_pc_itped_d
      WHERE itemuuid IN @lt_range
      INTO TABLE @rt_itens.
  ENDMETHOD.


  METHOD itens_em_pedidos_ativos.
    CHECK it_itens IS NOT INITIAL.

    DATA(lt_range) = VALUE tt_range_uuid( FOR i IN it_itens ( sign = 'I' option = 'EQ' low = i ) ).

    " Pedidos em andamento e pedidos em draft (ainda não ativados) numa única consulta
    SELECT ip~item_uuid
      FROM zta_pc_item_ped AS ip
      INNER JOIN zta_pc_pedido AS p ON p~pedido_uuid = ip~pedido_uuid
      WHERE ip~item_uuid IN @lt_range
        AND p~status_pedido IN ( @zif_pc_constants=>c_status_pedido-aberto,
                                 @zif_pc_constants=>c_status_pedido-aguardando_aprovacao,
                                 @zif_pc_constants=>c_status_pedido-processando_reembolso )
    UNION DISTINCT
    SELECT itemuuid AS item_uuid
      FROM zta_pc_itped_d
      WHERE itemuuid IN @lt_range
      INTO TABLE @rt_itens.
  ENDMETHOD.


  METHOD inativacao_bloqueada.
    CHECK it_saldo IS NOT INITIAL.

    DATA(lt_em_pedido_ativo) = itens_em_pedidos_ativos( VALUE #( FOR s IN it_saldo ( s-item_uuid ) ) ).

    " Regra: não inativar item com estoque disponível ou pedido ativo vinculado
    rt_bloqueados = VALUE #( FOR s IN it_saldo
                             ( LINES OF COND tt_uuid( WHEN s-estoque > s-reservada
                                                      THEN VALUE #( ( s-item_uuid ) ) ) ) ).
    INSERT LINES OF lt_em_pedido_ativo INTO TABLE rt_bloqueados.
  ENDMETHOD.


  METHOD precheck_update.
    " Só interessa a troca de ItemAtivo para inativo
    DATA(lt_inativar) = VALUE tt_saldo_item( FOR e IN entities
                                             WHERE ( %control-ItemAtivo = if_abap_behv=>mk-on
                                                     AND ItemAtivo      = abap_false )
                                             ( item_uuid = e-ItemUUID ) ).
    CHECK lt_inativar IS NOT INITIAL.

    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( QtdeEstoque QtdeReservada )
        WITH CORRESPONDING #( entities )
      RESULT DATA(lt_atuais).

    " Estoque informado no mesmo request prevalece sobre o atual
    DATA(lt_saldo) = VALUE tt_saldo_item(
      FOR e IN entities
      WHERE ( %control-ItemAtivo = if_abap_behv=>mk-on AND ItemAtivo = abap_false )
      LET ls_atual = VALUE #( lt_atuais[ %tky = e-%tky ] OPTIONAL )
      IN ( item_uuid = e-ItemUUID
           estoque   = COND #( WHEN e-%control-QtdeEstoque = if_abap_behv=>mk-on
                               THEN e-QtdeEstoque ELSE ls_atual-QtdeEstoque )
           reservada = ls_atual-QtdeReservada ) ).

    DATA(lt_bloqueados) = inativacao_bloqueada( lt_saldo ).
    CHECK lt_bloqueados IS NOT INITIAL.

    failed-item = VALUE #( FOR e IN entities
                           WHERE ( %control-ItemAtivo = if_abap_behv=>mk-on AND ItemAtivo = abap_false )
                           FOR b IN lt_bloqueados WHERE ( table_line = e-ItemUUID )
                           ( %tky = e-%tky ) ).

    reported-item = VALUE #( FOR f IN failed-item
                             ( %tky               = f-%tky
                               %msg               = NEW zcx_pc_msg( textid = zif_pc_msg=>item_inativacao_bloqueada )
                               %element-ItemAtivo = if_abap_behv=>mk-on ) ).
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
        is_draft  TYPE abp_behv_flag,
        item_uuid TYPE sysuuid_x16,
        sku       TYPE zr_pc_item-Sku,
        ativo     TYPE abap_boolean,
        estoque   TYPE i,
        reservada TYPE i,
        alterado  TYPE abap_boolean,
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
        lo_msg = NEW #( textid = zif_pc_msg=>item_estoque_concorrente attr1 = '?' ).
      ELSEIF <ls_mov>-qtde <= 0.
        lo_msg = NEW #( textid = zif_pc_msg=>item_qtde_invalida ).
      ELSE.
        CASE iv_tipo.
          WHEN c_movimento-reservar.
            IF <ls_saldo>-ativo = abap_false.
              lo_msg = NEW #( textid = zif_pc_msg=>item_inativo attr1 = <ls_saldo>-sku ).
            ELSEIF <ls_mov>-qtde > <ls_saldo>-estoque - <ls_saldo>-reservada.
              lo_msg = NEW #( textid = zif_pc_msg=>item_estoque_insuficiente
                              attr1  = <ls_saldo>-sku
                              attr2  = |{ <ls_saldo>-estoque - <ls_saldo>-reservada }| ).
            ELSE.
              <ls_saldo>-reservada += <ls_mov>-qtde.
            ENDIF.

          WHEN c_movimento-liberar.
            IF <ls_mov>-qtde > <ls_saldo>-reservada.
              lo_msg = NEW #( textid = zif_pc_msg=>item_reserva_inconsistente attr1 = <ls_saldo>-sku ).
            ELSE.
              <ls_saldo>-reservada -= <ls_mov>-qtde.
            ENDIF.

          WHEN c_movimento-baixar.
            IF <ls_mov>-qtde > <ls_saldo>-reservada OR <ls_mov>-qtde > <ls_saldo>-estoque.
              lo_msg = NEW #( textid = zif_pc_msg=>item_reserva_inconsistente attr1 = <ls_saldo>-sku ).
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

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_item\\Item.

    LOOP AT lt_itens INTO DATA(ls_item).
      " Sem categoria não há prefixo: ValidarItem acusa o campo obrigatório
      CHECK ls_item-Categoria IS NOT INITIAL.

      " SKU já gerado para a categoria atual é mantido. Se a categoria mudou
      " depois da primeira geração, o prefixo (SKU-XXX-...) ficou desatualizado
      " e o SKU é gerado de novo.
      IF strlen( ls_item-Sku ) >= 7
         AND ls_item-Sku+4(3) = zcl_pc_numeracao=>prefixo_categoria( ls_item-Categoria ).
        CONTINUE.
      ENDIF.

      TRY.
          APPEND VALUE #( %tky         = ls_item-%tky
                          Sku          = zcl_pc_numeracao=>gerar_sku( ls_item-Categoria )
                          %control-Sku = if_abap_behv=>mk-on ) TO lt_update.
        CATCH cx_number_ranges INTO DATA(lx_nr).
          APPEND VALUE #( %tky = ls_item-%tky
                          %msg = NEW zcx_pc_msg( textid   = zif_pc_msg=>numeracao_erro
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
        FIELDS ( Nome Categoria PrecoUnitario Currency )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    " Categorias válidas lidas uma única vez (fora do laço)
    SELECT Codigo
      FROM zr_pc_codelist
      WHERE Lista = @zif_pc_constants=>c_codelist-categoria
      INTO TABLE @DATA(lt_categorias).

    LOOP AT lt_itens INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item ) TO reported-item.

      IF ls_item-Nome IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>campo_obrigatorio attr1 = 'Nome' )
                        %element-Nome = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.

      IF ls_item-Categoria IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>campo_obrigatorio attr1 = 'Categoria' )
                        %element-Categoria = if_abap_behv=>mk-on ) TO reported-item.
      ELSEIF NOT line_exists( lt_categorias[ Codigo = ls_item-Categoria ] ).
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>valor_invalido attr1 = 'Categoria' )
                        %element-Categoria = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.

      IF ls_item-PrecoUnitario < 0.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>item_preco_invalido )
                        %element-PrecoUnitario = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.

      IF ls_item-Currency IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>campo_obrigatorio attr1 = 'Moeda' )
                        %element-Currency = if_abap_behv=>mk-on ) TO reported-item.
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
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>item_qtde_estoque_invalida
                                               attr1  = |{ ls_item-QtdeReservada }| )
                        %element-QtdeEstoque = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarInativacaoItem.
    READ ENTITIES OF zr_pc_item IN LOCAL MODE
      ENTITY Item
        FIELDS ( ItemAtivo QtdeEstoque QtdeReservada )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    " Mesma regra do precheck_update (estoque disponível ou pedido em andamento)
    DATA(lt_bloqueados) = inativacao_bloqueada( VALUE #( FOR i IN lt_itens WHERE ( ItemAtivo = abap_false )
                                                         ( item_uuid = i-ItemUUID
                                                           estoque   = i-QtdeEstoque
                                                           reservada = i-QtdeReservada ) ) ).

    LOOP AT lt_itens INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-inativacao ) TO reported-item.

      CHECK ls_item-ItemAtivo = abap_false.

      IF line_exists( lt_bloqueados[ table_line = ls_item-ItemUUID ] ).
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-inativacao
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>item_inativacao_bloqueada )
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

    " SKUs já gravados: uma única consulta para todos os itens validados
    DATA lt_chaves_sku TYPE STANDARD TABLE OF zta_pc_item-sku WITH EMPTY KEY.
    lt_chaves_sku = VALUE #( FOR i IN lt_itens WHERE ( Sku IS NOT INITIAL ) ( i-Sku ) ).
    IF lt_chaves_sku IS NOT INITIAL.
      SELECT item_uuid, sku
        FROM zta_pc_item
        FOR ALL ENTRIES IN @lt_chaves_sku
        WHERE sku = @lt_chaves_sku-table_line
        INTO TABLE @DATA(lt_sku_db).
    ENDIF.

    LOOP AT lt_itens INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-sku ) TO reported-item.

      " Em draft o SKU ainda não existe (gerado na ativação)
      IF ls_item-%is_draft = if_abap_behv=>mk-on.
        CONTINUE.
      ENDIF.

      IF ls_item-Sku IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-sku
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>campo_obrigatorio attr1 = 'SKU' ) ) TO reported-item.
        CONTINUE.
      ENDIF.

      DATA(lv_duplicado) = xsdbool( REDUCE i( INIT n = 0
                                              FOR d IN lt_sku_db
                                              WHERE ( sku = ls_item-Sku AND item_uuid <> ls_item-ItemUUID )
                                              NEXT n = n + 1 ) > 0 ).

      IF lv_duplicado = abap_true.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-sku
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>item_sku_duplicado )
                        %element-Sku = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
      CLEAR lv_duplicado.
    ENDLOOP.
  ENDMETHOD.


  METHOD ImportarPlanilha.
    TYPES:
      BEGIN OF ty_item,
        linha     TYPE i,
        nome      TYPE zr_pc_item-Nome,
        descricao TYPE zr_pc_item-Descricao,
        categoria TYPE zr_pc_item-Categoria,
        estoque   TYPE zr_pc_item-QtdeEstoque,
        preco     TYPE zr_pc_item-PrecoUnitario,
        moeda     TYPE zr_pc_item-Currency,
      END OF ty_item.

    CONSTANTS:
      BEGIN OF c_col,
        nome      TYPE string VALUE `Nome`,
        descricao TYPE string VALUE `Descrição`,
        categoria TYPE string VALUE `Categoria`,
        estoque   TYPE string VALUE `Quantidade em estoque`,
        preco     TYPE string VALUE `Preço unitário`,
        moeda     TYPE string VALUE `Moeda`,
      END OF c_col.

    DATA lt_colunas   TYPE zif_pc_planilha=>tt_colunas.
    DATA lt_erros     TYPE string_table.
    DATA lt_itens     TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.
    DATA lt_nomes_arq TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    lt_colunas = VALUE #(
      ( campo = c_col-nome      sinonimos = `NOMEDOITEM|PRODUTO|NOMEDOPRODUTO`                obrigatoria = abap_true )
      ( campo = c_col-descricao )
      ( campo = c_col-categoria obrigatoria = abap_true )
      ( campo = c_col-estoque   sinonimos = `ESTOQUE|QTDEESTOQUE|QUANTIDADE|QTDE|QUANTIDADEESTOQUE` obrigatoria = abap_true )
      ( campo = c_col-preco     sinonimos = `PRECO|VALOR|VALORUNITARIO|PRECOUNIT`             obrigatoria = abap_true )
      ( campo = c_col-moeda     sinonimos = `CURRENCY|MOEDACODIGO` ) ).

    " Dados de referência lidos uma única vez, fora dos laços: nomes já
    " cadastrados (evita duplicar o item ao reenviar a planilha) e moedas ISO
    SELECT nome FROM zta_pc_item INTO TABLE @DATA(lt_nomes_db).
    SELECT Currency FROM i_currency INTO TABLE @DATA(lt_moedas).

    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lt_erros, lt_itens, lt_nomes_arq.

      IF zcl_pc_auth=>admin_pode_criar( ) = abap_false.
        APPEND VALUE #( %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>sem_autorizacao ) ) TO reported-item.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-item.
        CONTINUE.
      ENDIF.

      " 1) Leitura do arquivo (XLSX ou CSV)
      zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = ls_key-%param-_StreamProperties-StreamProperty
                                      it_colunas   = lt_colunas
                            IMPORTING et_registros = DATA(lt_registros)
                                      et_erros     = lt_erros ).
      IF lt_erros IS NOT INITIAL.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 2) Validação linha a linha (todas as linhas são avaliadas antes de gravar)
      LOOP AT lt_registros INTO DATA(ls_reg).
        DATA(lv_pref)  = |Linha { ls_reg-linha }: |.
        DATA(lv_antes) = lines( lt_erros ).
        DATA(ls_item)  = VALUE ty_item( linha = ls_reg-linha ).

        DATA(lv_nome) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-nome ).
        IF lv_nome IS INITIAL.
          APPEND |{ lv_pref }Nome é obrigatório.| TO lt_erros.
        ELSEIF strlen( lv_nome ) > 120.
          APPEND |{ lv_pref }Nome excede 120 caracteres.| TO lt_erros.
        ELSE.
          " Evita criar o mesmo item duas vezes ao reenviar a mesma planilha
          DATA(lv_chave) = to_upper( lv_nome ).
          IF line_exists( lt_nomes_db[ nome = lv_nome ] ).
            APPEND |{ lv_pref }item "{ lv_nome }" já cadastrado.| TO lt_erros.
          ELSEIF line_exists( lt_nomes_arq[ table_line = lv_chave ] ).
            APPEND |{ lv_pref }item "{ lv_nome }" repetido na planilha.| TO lt_erros.
          ELSE.
            INSERT lv_chave INTO TABLE lt_nomes_arq.
            ls_item-nome = lv_nome.
          ENDIF.
        ENDIF.

        DATA(lv_descricao) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-descricao ).
        IF strlen( lv_descricao ) > 500.
          APPEND |{ lv_pref }Descrição excede 500 caracteres.| TO lt_erros.
        ELSE.
          ls_item-descricao = lv_descricao.
        ENDIF.

        DATA(lv_categoria_txt) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-categoria ).
        DATA(lv_categoria) = zcl_pc_importacao=>converter_codelist( iv_lista = zif_pc_constants=>c_codelist-categoria
                                                                    iv_texto = lv_categoria_txt ).
        IF lv_categoria IS INITIAL.
          APPEND |{ lv_pref }Categoria inválida ({ lv_categoria_txt }). Use: { zcl_pc_importacao=>opcoes_codelist( zif_pc_constants=>c_codelist-categoria ) }.| TO lt_erros.
        ELSE.
          ls_item-categoria = lv_categoria.
        ENDIF.

        DATA(lv_estoque_txt) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-estoque ).
        zcl_pc_planilha=>para_inteiro( EXPORTING iv_texto  = lv_estoque_txt
                                       IMPORTING ev_valor  = DATA(lv_estoque)
                                                 ev_valido = DATA(lv_estoque_ok) ).
        IF lv_estoque_ok = abap_false OR lv_estoque < 0.
          APPEND |{ lv_pref }Quantidade em estoque inválida ({ lv_estoque_txt }). Informe um inteiro maior ou igual a zero.| TO lt_erros.
        ELSE.
          ls_item-estoque = lv_estoque.
        ENDIF.

        DATA(lv_preco_txt) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-preco ).
        zcl_pc_planilha=>para_decimal( EXPORTING iv_texto  = lv_preco_txt
                                       IMPORTING ev_valor  = DATA(lv_preco)
                                                 ev_valido = DATA(lv_preco_ok) ).
        IF lv_preco_ok = abap_false OR lv_preco < 0 OR lv_preco > 9999999999999.
          APPEND |{ lv_pref }Preço unitário inválido ({ lv_preco_txt }). Informe um valor maior ou igual a zero.| TO lt_erros.
        ELSE.
          ls_item-preco = lv_preco.
        ENDIF.

        DATA(lv_moeda) = CONV waers( to_upper( zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-moeda ) ) ).
        IF lv_moeda IS INITIAL.
          lv_moeda = zif_pc_constants=>c_moeda_padrao.
        ENDIF.
        IF NOT line_exists( lt_moedas[ Currency = lv_moeda ] ).
          APPEND |{ lv_pref }Moeda inválida ({ lv_moeda }). Use o código ISO, por exemplo BRL.| TO lt_erros.
        ELSE.
          ls_item-moeda = lv_moeda.
        ENDIF.

        IF lines( lt_erros ) = lv_antes.
          APPEND ls_item TO lt_itens.
        ENDIF.
      ENDLOOP.

      IF lt_erros IS NOT INITIAL.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 3) Criação (instâncias ativas). O SKU é gerado aqui, na fase de interação
      "    (o intervalo de numeração ZPC_NR é bufferizado); a determination
      "    GerarSku do save mantém o SKU que já bate com a categoria.
      DATA lt_cria TYPE TABLE FOR CREATE zr_pc_item\\Item.
      CLEAR lt_cria.

      LOOP AT lt_itens INTO ls_item.
        TRY.
            DATA(lv_sku) = zcl_pc_numeracao=>gerar_sku( ls_item-categoria ).
          CATCH cx_number_ranges INTO DATA(lx_nr).
            APPEND |Linha { ls_item-linha }: não foi possível gerar o SKU ({ lx_nr->get_text( ) }).| TO lt_erros.
            CONTINUE.
        ENDTRY.

        APPEND VALUE #( %cid           = |ITM{ ls_item-linha }|
                        Sku            = lv_sku
                        Nome           = ls_item-nome
                        Descricao      = ls_item-descricao
                        Categoria      = ls_item-categoria
                        QtdeEstoque    = ls_item-estoque
                        PrecoUnitario  = ls_item-preco
                        Currency       = ls_item-moeda ) TO lt_cria.
      ENDLOOP.

      IF lt_erros IS NOT INITIAL.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_pc_item IN LOCAL MODE
        ENTITY Item
          CREATE FIELDS ( Sku Nome Descricao Categoria QtdeEstoque PrecoUnitario Currency )
          WITH lt_cria
        MAPPED   DATA(ls_mapped)
        FAILED   DATA(ls_failed)
        REPORTED DATA(ls_reported).

      IF ls_failed-item IS NOT INITIAL.
        APPEND `Não foi possível criar os itens.` TO lt_erros.
        LOOP AT ls_reported-item INTO DATA(ls_rep_item) WHERE %msg IS BOUND.
          APPEND |{ linha_do_cid( ls_rep_item-%cid ) }{ ls_rep_item-%msg->if_message~get_text( ) }| TO lt_erros.
        ENDLOOP.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %msg = zcx_pc_msg=>texto(
                               iv_texto    = |Importação concluída: { lines( lt_itens ) } item(ns) criado(s). Atualize a lista.|
                               iv_severity = if_abap_behv_message=>severity-success ) )
             TO reported-item.
    ENDLOOP.
  ENDMETHOD.


  METHOD falhar_importacao.
    APPEND VALUE #( %msg = zcx_pc_msg=>texto(
                             |Importação cancelada: nenhum item foi gravado ({ lines( it_erros ) } erro(s)).| ) )
           TO cs_reported-item.

    LOOP AT zcl_pc_importacao=>resumir_erros( it_erros ) INTO DATA(lv_erro).
      APPEND VALUE #( %msg = zcx_pc_msg=>texto( lv_erro ) ) TO cs_reported-item.
    ENDLOOP.

    APPEND VALUE #( %cid = iv_cid ) TO cs_failed-item.
  ENDMETHOD.


  METHOD linha_do_cid.
    DATA(lv_numero) = match( val = iv_cid pcre = `\d+` ).
    rv_texto = COND #( WHEN lv_numero IS NOT INITIAL THEN |Linha { lv_numero }: | ).
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
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>foto_formato_invalido )
                        %element-FotoItem = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
