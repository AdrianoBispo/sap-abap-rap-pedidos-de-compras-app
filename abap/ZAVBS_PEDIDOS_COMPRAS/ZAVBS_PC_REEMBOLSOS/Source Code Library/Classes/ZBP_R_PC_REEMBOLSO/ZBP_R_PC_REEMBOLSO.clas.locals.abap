*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
"! <h1>Handler da entidade Reembolso (BO {@link ZR_PC_REEMBOLSO})</h1>
"! Decisão das solicitações de reembolso. Aprovar e rejeitar processam todas
"! as solicitações em lote e chamam o BO {@link ZR_PC_PEDIDO} numa única
"! chamada EML (CancelarPorReembolso / RetomarPedido), na mesma LUW.
CLASS lhc_reembolso DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    "! Autorização global: criar e decidir exigem "executar" pedidos
    "! ({@link ZCL_PC_AUTH.METH:pedido_pode_executar}).
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Reembolso RESULT result.

    "! Feature control: decisões habilitadas só enquanto a solicitação está PENDENTE.
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

    "! Usuário técnico atual (DecididoPor); vazio se não puder ser obtido.
    "! @parameter rv_usuario | Usuário que decidiu o reembolso
    METHODS usuario_atual
      RETURNING VALUE(rv_usuario) TYPE zr_pc_reembolso-DecididoPor.

    "! Solicitação de reembolso lida por READ ENTITIES
    TYPES ts_reembolso      TYPE STRUCTURE FOR READ RESULT zr_pc_reembolso\\Reembolso.
    "! FAILED do BO Reembolso
    TYPES ty_failed         TYPE RESPONSE FOR FAILED EARLY zr_pc_reembolso.
    "! REPORTED do BO Reembolso
    TYPES ty_reported       TYPE RESPONSE FOR REPORTED EARLY zr_pc_reembolso.
    "! FAILED da chamada ao BO Pedido
    TYPES ty_failed_pedido  TYPE RESPONSE FOR FAILED EARLY zr_pc_pedido.
    "! REPORTED da chamada ao BO Pedido
    TYPES ty_reported_pedido TYPE RESPONSE FOR REPORTED EARLY zr_pc_pedido.

    TYPES:
      "! Solicitação de reembolso pendente e o motivo informado na decisão
      BEGIN OF ty_decisao,
        reembolso TYPE ts_reembolso,
        motivo    TYPE zr_pc_reembolso-MotivoDecisao,
      END OF ty_decisao,
      "! Decisões processadas em lote por {@link .METH:AprovarReembolso} e
      "! {@link .METH:RejeitarReembolso}
      tt_decisao TYPE STANDARD TABLE OF ty_decisao WITH EMPTY KEY.

    "! Repassa ao reembolso as mensagens e falhas que o BO Pedido devolveu
    "! (o vínculo é o PedidoUUID de cada solicitação).
    "! @parameter it_decisoes | Decisões enviadas ao BO Pedido
    "! @parameter is_failed_ped | FAILED da chamada ao BO Pedido
    "! @parameter is_rep_ped | REPORTED da chamada ao BO Pedido
    "! @parameter cs_failed | FAILED da action do reembolso
    "! @parameter cs_reported | REPORTED da action do reembolso
    METHODS repassar_pedido
      IMPORTING it_decisoes   TYPE tt_decisao
                is_failed_ped TYPE ty_failed_pedido
                is_rep_ped    TYPE ty_reported_pedido
      CHANGING  cs_failed     TYPE ty_failed
                cs_reported   TYPE ty_reported.

    "! Grava a decisão (status, motivo, data e usuário) de todos os
    "! reembolsos ainda sem falha numa única chamada EML e confirma cada um.
    "! @parameter it_decisoes | Decisões a gravar
    "! @parameter iv_status | Novo status (APROVADO ou REJEITADO)
    "! @parameter is_textid | Mensagem de sucesso (T100) com o número do pedido em &1
    "! @parameter cs_failed | FAILED da action do reembolso
    "! @parameter cs_reported | REPORTED da action do reembolso
    METHODS registrar_decisao
      IMPORTING it_decisoes TYPE tt_decisao
                iv_status   TYPE zr_pc_reembolso-StatusReembolso
                is_textid   TYPE scx_t100key
      CHANGING  cs_failed   TYPE ty_failed
                cs_reported TYPE ty_reported.
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
    DATA lt_decisoes TYPE tt_decisao.

    READ ENTITIES OF zr_pc_reembolso IN LOCAL MODE
      ENTITY Reembolso
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_reembolsos).

*---------------------------------------------------------------------*
    " 1) Solicitações ainda pendentes (memória)
*---------------------------------------------------------------------*

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

      APPEND VALUE #( reembolso = ls_reemb motivo = condense( ls_key-%param-MotivoDecisao ) ) TO lt_decisoes.
    ENDLOOP.

    CHECK lt_decisoes IS NOT INITIAL.

*---------------------------------------------------------------------*
    " 2) Pedidos: liberam a reserva, geram snapshots e são cancelados (mesma
    "    LUW), todos numa única chamada EML ao BO Pedido
*---------------------------------------------------------------------*

    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE CancelarPorReembolso
        FROM VALUE #( FOR d IN lt_decisoes
                      ( PedidoUUID = d-reembolso-PedidoUUID %is_draft = if_abap_behv=>mk-off ) )
      FAILED   DATA(ls_failed_ped)
      REPORTED DATA(ls_reported_ped).

    repassar_pedido( EXPORTING it_decisoes   = lt_decisoes
                               is_failed_ped = ls_failed_ped
                               is_rep_ped    = ls_reported_ped
                     CHANGING  cs_failed     = failed
                               cs_reported   = reported ).

*---------------------------------------------------------------------*
    " 3) Registra a decisão dos reembolsos cujo pedido foi cancelado
*---------------------------------------------------------------------*

    registrar_decisao( EXPORTING it_decisoes = lt_decisoes
                                 iv_status   = zif_pc_constants=>c_status_reembolso-aprovado
                                 is_textid   = zif_pc_msg=>reembolso_aprovado
                       CHANGING  cs_failed   = failed
                                 cs_reported = reported ).

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
    DATA lt_decisoes TYPE tt_decisao.

    READ ENTITIES OF zr_pc_reembolso IN LOCAL MODE
      ENTITY Reembolso
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_reembolsos).

*---------------------------------------------------------------------*
    " 1) Solicitações ainda pendentes e 2) motivo informado (memória)
*---------------------------------------------------------------------*

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

      APPEND VALUE #( reembolso = ls_reemb motivo = lv_motivo ) TO lt_decisoes.
    ENDLOOP.

    CHECK lt_decisoes IS NOT INITIAL.

*---------------------------------------------------------------------*
    " 3) Pedidos voltam ao status anterior à solicitação (mesma LUW),
    "    todos numa única chamada EML ao BO Pedido
*---------------------------------------------------------------------*

    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE RetomarPedido
        FROM VALUE #( FOR d IN lt_decisoes
                      ( PedidoUUID = d-reembolso-PedidoUUID
                        %is_draft  = if_abap_behv=>mk-off
                        %param     = VALUE #( StatusAnterior = d-reembolso-StatusPedidoAnterior ) ) )
      FAILED   DATA(ls_failed_ped)
      REPORTED DATA(ls_reported_ped).

    repassar_pedido( EXPORTING it_decisoes   = lt_decisoes
                               is_failed_ped = ls_failed_ped
                               is_rep_ped    = ls_reported_ped
                     CHANGING  cs_failed     = failed
                               cs_reported   = reported ).

*---------------------------------------------------------------------*
    " 4) Registra a decisão dos reembolsos cujo pedido foi retomado
*---------------------------------------------------------------------*

    registrar_decisao( EXPORTING it_decisoes = lt_decisoes
                                 iv_status   = zif_pc_constants=>c_status_reembolso-rejeitado
                                 is_textid   = zif_pc_msg=>reembolso_rejeitado
                       CHANGING  cs_failed   = failed
                                 cs_reported = reported ).

    READ ENTITIES OF zr_pc_reembolso IN LOCAL MODE
      ENTITY Reembolso ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).
    LOOP AT lt_resultado INTO DATA(ls_res).
      IF NOT line_exists( failed-reembolso[ ReembolsoUUID = ls_res-ReembolsoUUID ] ).
        APPEND VALUE #( %tky = ls_res-%tky %param = ls_res ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD repassar_pedido.

    " Mensagens do BO Pedido voltam para o reembolso do mesmo pedido
    LOOP AT is_rep_ped-pedido INTO DATA(ls_rep_ped) WHERE %msg IS BOUND.
      READ TABLE it_decisoes INTO DATA(ls_decisao) WITH KEY reembolso-PedidoUUID = ls_rep_ped-PedidoUUID.
      IF sy-subrc = 0.
        APPEND VALUE #( %tky = ls_decisao-reembolso-%tky %msg = ls_rep_ped-%msg ) TO cs_reported-reembolso.
      ELSE.
        APPEND VALUE #( %msg = ls_rep_ped-%msg ) TO cs_reported-reembolso.
      ENDIF.
    ENDLOOP.

    " Pedido recusado reprova a decisão do reembolso correspondente
    LOOP AT is_failed_ped-pedido INTO DATA(ls_fail_ped).
      READ TABLE it_decisoes INTO ls_decisao WITH KEY reembolso-PedidoUUID = ls_fail_ped-PedidoUUID.
      IF sy-subrc = 0 AND NOT line_exists( cs_failed-reembolso[ ReembolsoUUID = ls_decisao-reembolso-ReembolsoUUID ] ).
        APPEND VALUE #( %tky = ls_decisao-reembolso-%tky ) TO cs_failed-reembolso.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD registrar_decisao.

    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    DATA(lv_usuario) = usuario_atual( ).

    " Só as decisões cujo pedido aceitou a operação
    DATA lt_upd TYPE TABLE FOR UPDATE zr_pc_reembolso\\Reembolso.
    LOOP AT it_decisoes INTO DATA(ls_decisao).
      CHECK NOT line_exists( cs_failed-reembolso[ ReembolsoUUID = ls_decisao-reembolso-ReembolsoUUID ] ).
      APPEND VALUE #( %tky            = ls_decisao-reembolso-%tky
                      StatusReembolso = iv_status
                      MotivoDecisao   = ls_decisao-motivo
                      DataDecisao     = lv_agora
                      DecididoPor     = lv_usuario
                      %control = VALUE #( StatusReembolso = if_abap_behv=>mk-on
                                          MotivoDecisao   = if_abap_behv=>mk-on
                                          DataDecisao     = if_abap_behv=>mk-on
                                          DecididoPor     = if_abap_behv=>mk-on ) ) TO lt_upd.
    ENDLOOP.

    CHECK lt_upd IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_reembolso IN LOCAL MODE
      ENTITY Reembolso UPDATE FROM lt_upd
      FAILED   DATA(ls_failed_upd)
      REPORTED DATA(ls_reported_upd).

    APPEND LINES OF ls_failed_upd-reembolso TO cs_failed-reembolso.
    LOOP AT ls_reported_upd-reembolso INTO DATA(ls_rep_upd) WHERE %msg IS BOUND.
      APPEND ls_rep_upd TO cs_reported-reembolso.
    ENDLOOP.

    " Confirmação para cada reembolso decidido
    LOOP AT lt_upd INTO DATA(ls_upd).
      CHECK NOT line_exists( cs_failed-reembolso[ ReembolsoUUID = ls_upd-ReembolsoUUID ] ).
      READ TABLE it_decisoes INTO ls_decisao WITH KEY reembolso-ReembolsoUUID = ls_upd-ReembolsoUUID.
      APPEND VALUE #( %tky = ls_upd-%tky
                      %msg = zcx_pc_msg=>sucesso( textid = is_textid
                                                  attr1  = ls_decisao-reembolso-NumeroPedido ) )
             TO cs_reported-reembolso.
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
