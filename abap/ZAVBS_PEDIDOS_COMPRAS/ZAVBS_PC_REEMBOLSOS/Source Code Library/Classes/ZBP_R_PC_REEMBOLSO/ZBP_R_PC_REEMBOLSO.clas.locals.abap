*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
CLASS lhc_reembolso DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Reembolso RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Reembolso RESULT result.

    "! Aprova a solicitação: o pedido (PROCESSANDO_REEMBOLSO) é cancelado pelo
    "! BO Pedido (libera a reserva e gera os snapshots) na mesma LUW.
    METHODS AprovarReembolso FOR MODIFY
      IMPORTING keys FOR ACTION Reembolso~AprovarReembolso RESULT result.

    "! Rejeita a solicitação (motivo obrigatório): o pedido retoma o status
    "! em que estava antes do pedido de reembolso.
    METHODS RejeitarReembolso FOR MODIFY
      IMPORTING keys FOR ACTION Reembolso~RejeitarReembolso RESULT result.

    METHODS usuario_atual
      RETURNING VALUE(rv_usuario) TYPE zr_pc_reembolso-DecididoPor.
ENDCLASS.


CLASS lhc_reembolso IMPLEMENTATION.

  METHOD get_global_authorizations.
    DATA(lv_exec) = COND #( WHEN zcl_pc_auth=>pedido_pode_executar( ) = abap_true
                            THEN if_abap_behv=>auth-allowed
                            ELSE if_abap_behv=>auth-unauthorized ).
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = lv_exec.
    ENDIF.
    IF requested_authorizations-%action-AprovarReembolso = if_abap_behv=>mk-on.
      result-%action-AprovarReembolso = lv_exec.
    ENDIF.
    IF requested_authorizations-%action-RejeitarReembolso = if_abap_behv=>mk-on.
      result-%action-RejeitarReembolso = lv_exec.
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zr_pc_reembolso IN LOCAL MODE
      ENTITY Reembolso
        FIELDS ( StatusReembolso )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_reembolsos).

    " Decisão só enquanto a solicitação está pendente
    result = VALUE #(
      FOR r IN lt_reembolsos
      LET l_estado = COND #( WHEN r-StatusReembolso = zif_pc_constants=>c_status_reembolso-pendente
                             THEN if_abap_behv=>fc-o-enabled
                             ELSE if_abap_behv=>fc-o-disabled )
      IN
      ( %tky                      = r-%tky
        %action-AprovarReembolso  = l_estado
        %action-RejeitarReembolso = l_estado ) ).
  ENDMETHOD.


  METHOD AprovarReembolso.
    READ ENTITIES OF zr_pc_reembolso IN LOCAL MODE
      ENTITY Reembolso
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_reembolsos).

    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_reembolsos INTO DATA(ls_reemb) WITH KEY ReembolsoUUID = ls_key-ReembolsoUUID.
      CHECK sy-subrc = 0.

      " 1) Ainda pendente?
      IF ls_reemb-StatusReembolso <> zif_pc_constants=>c_status_reembolso-pendente.
        APPEND VALUE #( %tky = ls_reemb-%tky ) TO failed-reembolso.
        APPEND VALUE #( %tky = ls_reemb-%tky
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>reembolso_status_invalido ) )
               TO reported-reembolso.
        CONTINUE.
      ENDIF.

      " 2) Pedido: libera a reserva, gera snapshots e cancela (mesma LUW)
      MODIFY ENTITIES OF zr_pc_pedido
        ENTITY Pedido
          EXECUTE CancelarPorReembolso
          FROM VALUE #( ( PedidoUUID = ls_reemb-PedidoUUID %is_draft = if_abap_behv=>mk-off ) )
        FAILED   DATA(ls_failed_ped)
        REPORTED DATA(ls_reported_ped).

      LOOP AT ls_reported_ped-pedido INTO DATA(ls_rep_ped) WHERE %msg IS BOUND.
        APPEND VALUE #( %tky = ls_reemb-%tky %msg = ls_rep_ped-%msg ) TO reported-reembolso.
      ENDLOOP.
      IF ls_failed_ped-pedido IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_reemb-%tky ) TO failed-reembolso.
        CONTINUE.
      ENDIF.

      " 3) Registra a decisão
      MODIFY ENTITIES OF zr_pc_reembolso IN LOCAL MODE
        ENTITY Reembolso
          UPDATE FIELDS ( StatusReembolso MotivoDecisao DataDecisao DecididoPor )
          WITH VALUE #( ( %tky            = ls_reemb-%tky
                          StatusReembolso = zif_pc_constants=>c_status_reembolso-aprovado
                          MotivoDecisao   = condense( ls_key-%param-MotivoDecisao )
                          DataDecisao     = lv_agora
                          DecididoPor     = usuario_atual( ) ) )
        FAILED   DATA(ls_failed_upd)
        REPORTED DATA(ls_reported_upd).

      LOOP AT ls_reported_upd-reembolso INTO DATA(ls_rep_upd) WHERE %msg IS BOUND.
        APPEND VALUE #( %tky = ls_reemb-%tky %msg = ls_rep_upd-%msg ) TO reported-reembolso.
      ENDLOOP.
      IF ls_failed_upd-reembolso IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_reemb-%tky ) TO failed-reembolso.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_reemb-%tky
                      %msg = zcx_pc_msg=>sucesso( textid = zif_pc_msg=>reembolso_aprovado
                                                  attr1  = ls_reemb-NumeroPedido ) )
             TO reported-reembolso.
    ENDLOOP.

    READ ENTITIES OF zr_pc_reembolso IN LOCAL MODE
      ENTITY Reembolso ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).
    LOOP AT lt_resultado INTO DATA(ls_res).
      IF NOT line_exists( failed-reembolso[ ReembolsoUUID = ls_res-ReembolsoUUID ] ).
        APPEND VALUE #( %tky = ls_res-%tky %param = ls_res ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD RejeitarReembolso.
    READ ENTITIES OF zr_pc_reembolso IN LOCAL MODE
      ENTITY Reembolso
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_reembolsos).

    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_reembolsos INTO DATA(ls_reemb) WITH KEY ReembolsoUUID = ls_key-ReembolsoUUID.
      CHECK sy-subrc = 0.

      " 1) Ainda pendente?
      IF ls_reemb-StatusReembolso <> zif_pc_constants=>c_status_reembolso-pendente.
        APPEND VALUE #( %tky = ls_reemb-%tky ) TO failed-reembolso.
        APPEND VALUE #( %tky = ls_reemb-%tky
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>reembolso_status_invalido ) )
               TO reported-reembolso.
        CONTINUE.
      ENDIF.

      " 2) Motivo da rejeição é obrigatório
      DATA(lv_motivo) = CONV zr_pc_reembolso-MotivoDecisao( condense( ls_key-%param-MotivoDecisao ) ).
      IF lv_motivo IS INITIAL.
        APPEND VALUE #( %tky = ls_reemb-%tky ) TO failed-reembolso.
        APPEND VALUE #( %tky = ls_reemb-%tky
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>reembolso_motivo_decisao_obrig ) )
               TO reported-reembolso.
        CONTINUE.
      ENDIF.

      " 3) Pedido volta ao status anterior à solicitação (mesma LUW)
      MODIFY ENTITIES OF zr_pc_pedido
        ENTITY Pedido
          EXECUTE RetomarPedido
          FROM VALUE #( ( PedidoUUID = ls_reemb-PedidoUUID
                          %is_draft  = if_abap_behv=>mk-off
                          %param     = VALUE #( StatusAnterior = ls_reemb-StatusPedidoAnterior ) ) )
        FAILED   DATA(ls_failed_ped)
        REPORTED DATA(ls_reported_ped).

      LOOP AT ls_reported_ped-pedido INTO DATA(ls_rep_ped) WHERE %msg IS BOUND.
        APPEND VALUE #( %tky = ls_reemb-%tky %msg = ls_rep_ped-%msg ) TO reported-reembolso.
      ENDLOOP.
      IF ls_failed_ped-pedido IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_reemb-%tky ) TO failed-reembolso.
        CONTINUE.
      ENDIF.

      " 4) Registra a decisão
      MODIFY ENTITIES OF zr_pc_reembolso IN LOCAL MODE
        ENTITY Reembolso
          UPDATE FIELDS ( StatusReembolso MotivoDecisao DataDecisao DecididoPor )
          WITH VALUE #( ( %tky            = ls_reemb-%tky
                          StatusReembolso = zif_pc_constants=>c_status_reembolso-rejeitado
                          MotivoDecisao   = lv_motivo
                          DataDecisao     = lv_agora
                          DecididoPor     = usuario_atual( ) ) )
        FAILED   DATA(ls_failed_upd)
        REPORTED DATA(ls_reported_upd).

      LOOP AT ls_reported_upd-reembolso INTO DATA(ls_rep_upd) WHERE %msg IS BOUND.
        APPEND VALUE #( %tky = ls_reemb-%tky %msg = ls_rep_upd-%msg ) TO reported-reembolso.
      ENDLOOP.
      IF ls_failed_upd-reembolso IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_reemb-%tky ) TO failed-reembolso.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_reemb-%tky
                      %msg = zcx_pc_msg=>sucesso( textid = zif_pc_msg=>reembolso_rejeitado
                                                  attr1  = ls_reemb-NumeroPedido ) )
             TO reported-reembolso.
    ENDLOOP.

    READ ENTITIES OF zr_pc_reembolso IN LOCAL MODE
      ENTITY Reembolso ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).
    LOOP AT lt_resultado INTO DATA(ls_res).
      IF NOT line_exists( failed-reembolso[ ReembolsoUUID = ls_res-ReembolsoUUID ] ).
        APPEND VALUE #( %tky = ls_res-%tky %param = ls_res ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD usuario_atual.
    TRY.
        rv_usuario = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        CLEAR rv_usuario.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
