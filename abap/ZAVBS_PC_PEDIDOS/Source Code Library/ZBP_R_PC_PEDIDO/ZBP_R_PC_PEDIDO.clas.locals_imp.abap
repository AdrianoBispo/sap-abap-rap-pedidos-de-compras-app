*"* Local Types da behavior pool ZBP_R_PC_PEDIDO

"! Handler da entidade Pedido (root)
CLASS lhc_pedido DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_mov,
        reservar TYPE c LENGTH 1 VALUE 'R',
        liberar  TYPE c LENGTH 1 VALUE 'L',
        baixar   TYPE c LENGTH 1 VALUE 'B',
      END OF c_mov.

    CONSTANTS:
      BEGIN OF c_area,
        cliente  TYPE string VALUE `VALIDAR_CLIENTE`,
        registro TYPE string VALUE `VALIDAR_REGISTRO`,
      END OF c_area.

    TYPES:
      BEGIN OF ty_pedido_key,
        is_draft    TYPE abp_behv_flag,
        pedido_uuid TYPE sysuuid_x16,
      END OF ty_pedido_key,
      tt_pedido_key TYPE STANDARD TABLE OF ty_pedido_key WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_qtde_item,
        item_uuid TYPE sysuuid_x16,
        qtde      TYPE i,
      END OF ty_qtde_item,
      tt_qtde_item TYPE SORTED TABLE OF ty_qtde_item WITH UNIQUE KEY item_uuid.

    TYPES:
      BEGIN OF ty_endereco,
        endereco_uuid TYPE sysuuid_x16,
        completo      TYPE zr_pc_pedido-EnderecoPrincipalCompleto,
      END OF ty_endereco.

    TYPES ts_pedido        TYPE STRUCTURE FOR READ RESULT zr_pc_pedido\\Pedido.
    TYPES tt_itens_pedido  TYPE TABLE FOR READ RESULT zr_pc_pedido\\Pedido\_Itens.
    TYPES ty_failed        TYPE RESPONSE FOR FAILED EARLY zr_pc_pedido.
    TYPES ty_reported      TYPE RESPONSE FOR REPORTED EARLY zr_pc_pedido.

    " Falhas da reserva de estoque no registro. Uma determination não tem
    " FAILED e não aborta o Save; ValidarRegistro lê esta tabela na gravação
    " do pedido recém-registrado e reprova o salvamento com estas mensagens.
    TYPES:
      BEGIN OF ty_falha_registro,
        pedido_uuid TYPE sysuuid_x16,
        msg         TYPE REF TO if_abap_behv_message,
      END OF ty_falha_registro.
    CLASS-DATA gt_falhas_registro TYPE STANDARD TABLE OF ty_falha_registro WITH EMPTY KEY.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Pedido RESULT result.

    "! Importação em massa por planilha (.xlsx/.csv): uma linha por item, com a
    "! mesma referência para os itens de um pedido. Cria pedidos ativos (CRIADO)
    "! e reserva o estoque, como o registro pela tela. Tudo ou nada.
    METHODS ImportarPlanilha FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~ImportarPlanilha.

    "! Reporta os erros da importação (primeiro o resumo) e falha a action,
    "! o que descarta qualquer pedido já criado no buffer.
    METHODS falhar_importacao
      IMPORTING it_erros    TYPE string_table
                iv_cid      TYPE abp_behv_cid
      CHANGING  cs_failed   TYPE ty_failed
                cs_reported TYPE ty_reported.

    "! "Linha N: " a partir do %cid (PED ou ITM seguido do número da linha).
    METHODS linha_do_cid
      IMPORTING iv_cid          TYPE csequence
      RETURNING VALUE(rv_texto) TYPE string.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Pedido RESULT result.

    METHODS DefinirStatusInicial FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Pedido~DefinirStatusInicial.

    METHODS AtualizarEndereco FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Pedido~AtualizarEndereco.

    METHODS GerarNumeroPedido FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Pedido~GerarNumeroPedido.

    METHODS CalcularTotalPedido FOR DETERMINE ON SAVE
      IMPORTING keys FOR Pedido~CalcularTotalPedido.

    METHODS AtualizarFlagsStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Pedido~AtualizarFlagsStatus.

    METHODS ValidarCliente FOR VALIDATE ON SAVE
      IMPORTING keys FOR Pedido~ValidarCliente.

    METHODS RecalcularTotal FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~RecalcularTotal.

    "! Reserva o estoque dos itens quando o rascunho é salvo e o pedido passa
    "! a existir como instância ativa (status CRIADO).
    METHODS ReservarEstoqueRegistro FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Pedido~ReservarEstoqueRegistro.

    "! Corpo da reserva (FAILED/REPORTED não existem em determination).
    METHODS reservar_registro
      IMPORTING it_keys  TYPE tt_pedido_key
      CHANGING  failed   TYPE ty_failed
                reported TYPE ty_reported.

    "! Checagens do Save (Prepare): endereço principal, itens e disponibilidade.
    METHODS ValidarRegistro FOR VALIDATE ON SAVE
      IMPORTING keys FOR Pedido~ValidarRegistro.

    METHODS SimularPagamento FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~SimularPagamento RESULT result.

    METHODS AprovarPedido FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~AprovarPedido RESULT result.

    METHODS CancelarPedido FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~CancelarPedido RESULT result.

    "! Chamada pelo BO Reembolso ao aprovar o reembolso: libera a reserva,
    "! gera os snapshots e cancela o pedido (PROCESSAR_REEMBOLSO -> CANCELADO).
    METHODS CancelarPorReembolso FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~CancelarPorReembolso RESULT result.

    "! Chamada pelo BO Reembolso ao rejeitar o reembolso: o pedido retoma o
    "! status anterior à solicitação (informado no parâmetro).
    METHODS RetomarPedido FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~RetomarPedido RESULT result.

    "! Precheck: item com estoque disponível zerado não pode nem ser
    "! adicionado ao pedido (feedback imediato, antes do save).
    METHODS precheck_criar_item FOR PRECHECK
      IMPORTING keys FOR CREATE Pedido\_Itens.

    "! Soma ValorTotal dos itens e atualiza o total do pedido.
    "! Devolve o reported da chamada EML para o handler chamador avaliar.
    METHODS recalcular_totais
      IMPORTING it_pedidos         TYPE tt_pedido_key
      RETURNING VALUE(rs_reported) TYPE ty_reported.

    "! Endereço principal atual do cliente (vazio se não houver).
    METHODS endereco_principal
      IMPORTING iv_cliente_uuid    TYPE sysuuid_x16
      RETURNING VALUE(rs_endereco) TYPE ty_endereco.

    "! Quantidade total por item (o mesmo item pode estar em mais de uma linha).
    METHODS somar_quantidades
      IMPORTING it_itens       TYPE tt_itens_pedido
      RETURNING VALUE(rt_qtde) TYPE tt_qtde_item.

    "! Executa ReservarEstoque / LiberarReserva / BaixarEstoque no BO Item
    "! (EML entre BOs, mesma LUW). Em falha parcial de reserva, libera o
    "! que já foi reservado (compensação) e reporta o erro no pedido.
    METHODS movimentar_estoque
      IMPORTING iv_acao     TYPE c
                is_pedido   TYPE ts_pedido
                it_qtde     TYPE tt_qtde_item
      EXPORTING ev_ok       TYPE abap_boolean
      CHANGING  cs_failed   TYPE ty_failed
                cs_reported TYPE ty_reported.

    "! Pagamento já efetuado: em vez de cancelar direto, cria a solicitação
    "! de reembolso (PENDENTE) e move o pedido para PROCESSAR_REEMBOLSO.
    "! O estoque permanece reservado até a decisão (AprovarReembolso/RejeitarReembolso).
    METHODS iniciar_processo_reembolso
      IMPORTING is_pedido   TYPE ts_pedido
                iv_motivo   TYPE csequence
      CHANGING  cs_failed   TYPE ty_failed
                cs_reported TYPE ty_reported.

    "! Congela cliente, endereço e itens no encerramento do pedido.
    METHODS criar_snapshots
      IMPORTING is_pedido   TYPE ts_pedido
                it_itens    TYPE tt_itens_pedido
                iv_motivo   TYPE csequence
      CHANGING  cs_failed   TYPE ty_failed
                cs_reported TYPE ty_reported.

    METHODS registrar_erro
      IMPORTING is_pedido   TYPE ts_pedido
                io_msg      TYPE REF TO zcx_pc_msg
      CHANGING  cs_failed   TYPE ty_failed
                cs_reported TYPE ty_reported.

    "! Propaga failed/reported de uma chamada EML para a resposta da action.
    "! Nenhuma chamada EML deve ser feita sem avaliar o retorno.
    METHODS propagar
      IMPORTING is_failed   TYPE ty_failed OPTIONAL
                is_reported TYPE ty_reported OPTIONAL
      CHANGING  cs_failed   TYPE ty_failed
                cs_reported TYPE ty_reported.

    METHODS erro_status
      IMPORTING is_pedido     TYPE ts_pedido
      RETURNING VALUE(ro_msg) TYPE REF TO zcx_pc_msg.
ENDCLASS.


CLASS lhc_pedido IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Cada operação verifica sua própria atividade (ACTVT)
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = COND #( WHEN zcl_pc_auth=>pedido_pode_criar( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = COND #( WHEN zcl_pc_auth=>pedido_pode_alterar( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = COND #( WHEN zcl_pc_auth=>pedido_pode_excluir( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-Edit = if_abap_behv=>mk-on.
      result-%action-Edit = COND #( WHEN zcl_pc_auth=>pedido_pode_alterar( ) = abap_true
                                    THEN if_abap_behv=>auth-allowed
                                    ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    DATA(lv_exec) = COND #( WHEN zcl_pc_auth=>pedido_pode_executar( ) = abap_true
                            THEN if_abap_behv=>auth-allowed
                            ELSE if_abap_behv=>auth-unauthorized ).

    IF requested_authorizations-%action-SimularPagamento = if_abap_behv=>mk-on.
      result-%action-SimularPagamento = lv_exec.
    ENDIF.
    IF requested_authorizations-%action-AprovarPedido = if_abap_behv=>mk-on.
      result-%action-AprovarPedido = lv_exec.
    ENDIF.
    IF requested_authorizations-%action-CancelarPedido = if_abap_behv=>mk-on.
      result-%action-CancelarPedido = lv_exec.
    ENDIF.
    IF requested_authorizations-%action-ImportarPlanilha = if_abap_behv=>mk-on.
      result-%action-ImportarPlanilha = COND #( WHEN zcl_pc_auth=>pedido_pode_criar( ) = abap_true
                                                THEN if_abap_behv=>auth-allowed
                                                ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        FIELDS ( StatusPedido )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos).

    result = VALUE #(
      FOR p IN lt_pedidos
      LET l_ativo      = xsdbool( p-%is_draft = if_abap_behv=>mk-off )
          l_criado     = xsdbool( p-StatusPedido = zif_pc_constants=>c_status_pedido-criado )
          l_ag_pag     = xsdbool( p-StatusPedido = zif_pc_constants=>c_status_pedido-aguardando_pagamento )
          l_ag_apr     = xsdbool( p-StatusPedido = zif_pc_constants=>c_status_pedido-aguardando_aprovacao )
          l_on         = if_abap_behv=>fc-o-enabled
          l_off        = if_abap_behv=>fc-o-disabled
      IN
      ( %tky                     = p-%tky
        " O estoque é reservado no registro (Save do rascunho): o pedido ativo
        " não é editado nem excluído, só cancelado. Itens só entram no rascunho.
        %delete                  = COND #( WHEN l_ativo = abap_false THEN l_on ELSE l_off )
        %action-Edit             = l_off
        %assoc-_Itens            = COND #( WHEN l_ativo = abap_false THEN l_on ELSE l_off )
        " Ações do ciclo de vida somente sobre a instância ativa (não em draft)
        %action-SimularPagamento = COND #( WHEN l_ativo = abap_true
                                            AND ( l_criado = abap_true OR l_ag_pag = abap_true )
                                           THEN l_on ELSE l_off )
        %action-AprovarPedido    = COND #( WHEN l_ativo = abap_true AND l_ag_apr = abap_true THEN l_on ELSE l_off )
        %action-CancelarPedido   = COND #( WHEN l_ativo = abap_true
                                            AND ( l_criado = abap_true OR l_ag_pag = abap_true OR l_ag_apr = abap_true )
                                           THEN l_on ELSE l_off ) ) ).
  ENDMETHOD.


  METHOD DefinirStatusInicial.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        FIELDS ( StatusPedido )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos).

    DELETE lt_pedidos WHERE StatusPedido IS NOT INITIAL.
    CHECK lt_pedidos IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        UPDATE FIELDS ( StatusPedido StatusPagamento Currency ValorTotal )
        WITH VALUE #( FOR p IN lt_pedidos
                      ( %tky            = p-%tky
                        StatusPedido    = zif_pc_constants=>c_status_pedido-criado
                        StatusPagamento = zif_pc_constants=>c_status_pagamento-pendente
                        Currency        = zif_pc_constants=>c_moeda_padrao
                        ValorTotal      = 0 ) )
      REPORTED DATA(ls_reported_ini).

    LOOP AT ls_reported_ini-pedido INTO DATA(ls_rep_ini) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_ini ) TO reported-pedido.
    ENDLOOP.
  ENDMETHOD.


  METHOD AtualizarEndereco.
    " Side effect: ao trocar o cliente, usa o endereço principal atual.
    " Não gera snapshot e não remove itens do pedido.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        FIELDS ( ClienteUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos).

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      DATA(ls_endereco) = endereco_principal( ls_pedido-ClienteUUID ).
      APPEND VALUE #( %tky                      = ls_pedido-%tky
                      EnderecoUUID              = ls_endereco-endereco_uuid
                      EnderecoPrincipalCompleto = ls_endereco-completo
                      %control = VALUE #( EnderecoUUID              = if_abap_behv=>mk-on
                                          EnderecoPrincipalCompleto = if_abap_behv=>mk-on ) ) TO lt_update.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido UPDATE FROM lt_update
      REPORTED DATA(ls_reported_d1).

    LOOP AT ls_reported_d1-pedido INTO DATA(ls_rep_d1) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_d1 ) TO reported-pedido.
    ENDLOOP.
  ENDMETHOD.


  METHOD GerarNumeroPedido.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        FIELDS ( NumeroPedido )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos).

    DELETE lt_pedidos WHERE NumeroPedido IS NOT INITIAL.
    CHECK lt_pedidos IS NOT INITIAL.

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      TRY.
          APPEND VALUE #( %tky                  = ls_pedido-%tky
                          NumeroPedido          = zcl_pc_numeracao=>proximo_numero_pedido( )
                          %control-NumeroPedido = if_abap_behv=>mk-on ) TO lt_update.
        CATCH cx_number_ranges INTO DATA(lx_nr).
          APPEND VALUE #( %tky = ls_pedido-%tky
                          %msg = NEW zcx_pc_msg( textid   = zcx_pc_msg=>numeracao_erro
                                                 attr1    = lx_nr->get_text( )
                                                 previous = lx_nr ) ) TO reported-pedido.
      ENDTRY.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido UPDATE FROM lt_update
      REPORTED DATA(ls_reported_d2).

    LOOP AT ls_reported_d2-pedido INTO DATA(ls_rep_d2) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_d2 ) TO reported-pedido.
    ENDLOOP.
  ENDMETHOD.


  METHOD CalcularTotalPedido.
    DATA(ls_reported_tot) = recalcular_totais(
      VALUE #( FOR k IN keys ( is_draft = k-%is_draft pedido_uuid = k-PedidoUUID ) ) ).

    LOOP AT ls_reported_tot-pedido INTO DATA(ls_rep_tot) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_tot ) TO reported-pedido.
    ENDLOOP.
  ENDMETHOD.


  METHOD RecalcularTotal.
    DATA(ls_reported_tot) = recalcular_totais(
      VALUE #( FOR k IN keys ( is_draft = k-%is_draft pedido_uuid = k-PedidoUUID ) ) ).

    LOOP AT ls_reported_tot-pedido INTO DATA(ls_rep_tot) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_tot ) TO reported-pedido.
    ENDLOOP.
  ENDMETHOD.


  METHOD precheck_criar_item.
    " keys traz o %target (tabela) com o que já foi digitado na linha nova
    " (ItemUUID escolhido via value help) - dá pra reprovar na hora,
    " antes do save, se o item estiver sem estoque disponível.
    DATA lt_item_uuid TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    LOOP AT keys INTO DATA(ls_k0).
      LOOP AT ls_k0-%target INTO DATA(ls_target0) WHERE ItemUUID IS NOT INITIAL.
        INSERT ls_target0-ItemUUID INTO TABLE lt_item_uuid.
      ENDLOOP.
    ENDLOOP.
    CHECK lt_item_uuid IS NOT INITIAL.

    SELECT ItemUUID, Sku, QtdeDisponivel
      FROM zr_pc_item
      FOR ALL ENTRIES IN @lt_item_uuid
      WHERE ItemUUID = @lt_item_uuid-table_line
      INTO TABLE @DATA(lt_estoque).

    LOOP AT keys INTO DATA(ls_key).
      LOOP AT ls_key-%target INTO DATA(ls_target) WHERE ItemUUID IS NOT INITIAL.
        READ TABLE lt_estoque INTO DATA(ls_estoque) WITH KEY ItemUUID = ls_target-ItemUUID.
        CHECK sy-subrc = 0 AND ls_estoque-QtdeDisponivel <= 0.

        APPEND VALUE #( %cid = ls_target-%cid %is_draft = ls_key-%is_draft ) TO failed-itempedido.
        APPEND VALUE #( %cid = ls_target-%cid %is_draft = ls_key-%is_draft
                        %msg = NEW zcx_pc_msg( textid = zcx_pc_msg=>item_sem_estoque
                                               attr1  = ls_estoque-Sku ) ) TO reported-itempedido.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD AtualizarFlagsStatus.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        FIELDS ( StatusPedido PedidoEncerrado PedidoAtivoSemHistorico )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos).

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      DATA(lv_encerrado) = xsdbool( ls_pedido-StatusPedido = zif_pc_constants=>c_status_pedido-finalizado
                                 OR ls_pedido-StatusPedido = zif_pc_constants=>c_status_pedido-cancelado ).
      DATA(lv_ativo_sh)  = xsdbool( ls_pedido-StatusPedido = zif_pc_constants=>c_status_pedido-criado
                                 OR ls_pedido-StatusPedido = zif_pc_constants=>c_status_pedido-aguardando_pagamento
                                 OR ls_pedido-StatusPedido = zif_pc_constants=>c_status_pedido-aguardando_aprovacao ).

      IF lv_encerrado <> ls_pedido-PedidoEncerrado OR lv_ativo_sh <> ls_pedido-PedidoAtivoSemHistorico.
        APPEND VALUE #( %tky                    = ls_pedido-%tky
                        PedidoEncerrado         = lv_encerrado
                        PedidoAtivoSemHistorico = lv_ativo_sh
                        %control = VALUE #( PedidoEncerrado         = if_abap_behv=>mk-on
                                            PedidoAtivoSemHistorico = if_abap_behv=>mk-on ) ) TO lt_update.
      ENDIF.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido UPDATE FROM lt_update
      REPORTED DATA(ls_reported_flags).

    LOOP AT ls_reported_flags-pedido INTO DATA(ls_rep_flags) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_flags ) TO reported-pedido.
    ENDLOOP.
  ENDMETHOD.


  METHOD recalcular_totais.
    CHECK it_pedidos IS NOT INITIAL.

    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        FIELDS ( ValorTotal Currency )
        WITH VALUE #( FOR k IN it_pedidos ( %is_draft = k-is_draft PedidoUUID = k-pedido_uuid ) )
      RESULT DATA(lt_pedidos)
      ENTITY Pedido BY \_Itens
        FIELDS ( PedidoUUID ValorTotal )
        WITH VALUE #( FOR k IN it_pedidos ( %is_draft = k-is_draft PedidoUUID = k-pedido_uuid ) )
      RESULT DATA(lt_itens).

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      DATA(lv_total) = CONV zr_pc_pedido-ValorTotal( 0 ).
      LOOP AT lt_itens INTO DATA(ls_item)
           WHERE PedidoUUID = ls_pedido-PedidoUUID AND %is_draft = ls_pedido-%is_draft.
        lv_total += ls_item-ValorTotal.
      ENDLOOP.

      IF lv_total <> ls_pedido-ValorTotal OR ls_pedido-Currency IS INITIAL.
        APPEND VALUE #( %tky       = ls_pedido-%tky
                        ValorTotal = lv_total
                        Currency   = COND #( WHEN ls_pedido-Currency IS INITIAL
                                             THEN zif_pc_constants=>c_moeda_padrao
                                             ELSE ls_pedido-Currency )
                        %control = VALUE #( ValorTotal = if_abap_behv=>mk-on
                                            Currency   = if_abap_behv=>mk-on ) ) TO lt_update.
      ENDIF.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido UPDATE FROM lt_update
      REPORTED rs_reported.
  ENDMETHOD.


  METHOD ValidarCliente.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        FIELDS ( ClienteUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos).

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-cliente ) TO reported-pedido.

      IF ls_pedido-ClienteUUID IS INITIAL.
        APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-cliente
                        %msg = NEW zcx_pc_msg( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Cliente' )
                        %element-ClienteUUID = if_abap_behv=>mk-on ) TO reported-pedido.
        CONTINUE.
      ENDIF.

      SELECT SINGLE ClienteAtivo
        FROM zr_pc_cliente
        WHERE ClienteUUID = @ls_pedido-ClienteUUID
        INTO @DATA(lv_ativo).

      IF sy-subrc <> 0 OR lv_ativo = abap_false.
        APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-cliente
                        %msg = NEW zcx_pc_msg( textid = zcx_pc_msg=>cliente_inativo )
                        %element-ClienteUUID = if_abap_behv=>mk-on ) TO reported-pedido.
        CONTINUE.
      ENDIF.

      " Sem endereço principal: apenas alerta no salvamento; a confirmação é bloqueada
      DATA(ls_endereco) = endereco_principal( ls_pedido-ClienteUUID ).
      IF ls_endereco-endereco_uuid IS INITIAL.
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-cliente
                        %msg = NEW zcx_pc_msg( textid   = zcx_pc_msg=>cliente_sem_endereco_principal
                                               severity = if_abap_behv_message=>severity-warning )
                        %element-ClienteUUID = if_abap_behv=>mk-on ) TO reported-pedido.
      ENDIF.
      CLEAR lv_ativo.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarRegistro.
    " Save (Prepare) do rascunho: o pedido só é registrado se o cliente tiver
    " endereço principal, houver itens e o estoque disponível cobrir as
    " quantidades. Vale só para o rascunho: depois do registro o estoque já
    " está reservado e a disponibilidade deixaria de bater com o pedido.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        FIELDS ( ClienteUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos)
      ENTITY Pedido BY \_Itens
        FIELDS ( PedidoUUID ItemUUID QtdeItemPedido )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      " Pedido ativo recém-registrado: devolve as falhas da reserva de estoque
      " (ReservarEstoqueRegistro não pode falhar o Save por conta própria)
      IF ls_pedido-%is_draft = if_abap_behv=>mk-off.
        LOOP AT gt_falhas_registro INTO DATA(ls_falha) WHERE pedido_uuid = ls_pedido-PedidoUUID.
          IF NOT line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
            APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
          ENDIF.
          APPEND VALUE #( %tky = ls_pedido-%tky %msg = ls_falha-msg ) TO reported-pedido.
        ENDLOOP.
        DELETE gt_falhas_registro WHERE pedido_uuid = ls_pedido-PedidoUUID.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-registro ) TO reported-pedido.

      " Cliente inexistente/inativo já é acusado por ValidarCliente
      IF ls_pedido-ClienteUUID IS NOT INITIAL
         AND endereco_principal( ls_pedido-ClienteUUID )-endereco_uuid IS INITIAL.
        APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-registro
                        %msg = NEW zcx_pc_msg( textid = zcx_pc_msg=>cliente_sem_endereco_principal )
                        %element-ClienteUUID = if_abap_behv=>mk-on ) TO reported-pedido.
      ENDIF.

      DATA(lt_itens_ped) = VALUE tt_itens_pedido( FOR i IN lt_itens
                                                  WHERE ( PedidoUUID = ls_pedido-PedidoUUID
                                                          AND %is_draft = ls_pedido-%is_draft )
                                                  ( i ) ).
      IF lt_itens_ped IS INITIAL.
        APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-registro
                        %msg = NEW zcx_pc_msg( textid = zcx_pc_msg=>pedido_sem_itens ) ) TO reported-pedido.
        CONTINUE.
      ENDIF.

      DATA(lt_qtde) = somar_quantidades( lt_itens_ped ).
      SELECT ItemUUID, Sku, QtdeEstoque, QtdeReservada
        FROM zr_pc_item
        FOR ALL ENTRIES IN @lt_qtde
        WHERE ItemUUID = @lt_qtde-item_uuid
        INTO TABLE @DATA(lt_estoque).

      LOOP AT lt_qtde INTO DATA(ls_qtde) WHERE item_uuid IS NOT INITIAL.
        READ TABLE lt_estoque INTO DATA(ls_estoque) WITH KEY ItemUUID = ls_qtde-item_uuid.
        IF sy-subrc = 0 AND ls_qtde-qtde > ls_estoque-QtdeEstoque - ls_estoque-QtdeReservada.
          APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
          APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-registro
                          %msg = NEW zcx_pc_msg( textid = zcx_pc_msg=>item_estoque_insuficiente
                                                 attr1  = ls_estoque-Sku
                                                 attr2  = |{ ls_estoque-QtdeEstoque - ls_estoque-QtdeReservada }| ) )
                 TO reported-pedido.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD ImportarPlanilha.
    TYPES:
      BEGIN OF ty_linha,
        linha        TYPE i,
        ref          TYPE string,
        cpf          TYPE zr_pc_cliente-Cpf,
        sku          TYPE zr_pc_item-Sku,
        qtde         TYPE i,
        obs          TYPE string,
        cliente_uuid TYPE sysuuid_x16,
        item_uuid    TYPE sysuuid_x16,
      END OF ty_linha.
    TYPES:
      BEGIN OF ty_grupo,
        ref          TYPE string,
        linha        TYPE i,
        cpf          TYPE zr_pc_cliente-Cpf,
        cliente_uuid TYPE sysuuid_x16,
        obs          TYPE string,
      END OF ty_grupo.
    TYPES:
      BEGIN OF ty_cli_status,
        cpf          TYPE zr_pc_cliente-Cpf,
        cliente_uuid TYPE sysuuid_x16,
        motivo       TYPE string,
      END OF ty_cli_status.
    TYPES:
      BEGIN OF ty_demanda,
        item_uuid  TYPE sysuuid_x16,
        solicitado TYPE i,
      END OF ty_demanda.

    CONSTANTS:
      BEGIN OF c_col,
        ref        TYPE string VALUE `Pedido`,
        cpf        TYPE string VALUE `CPF`,
        sku        TYPE string VALUE `SKU`,
        quantidade TYPE string VALUE `Quantidade`,
        obs        TYPE string VALUE `Observação`,
      END OF c_col.

    FIELD-SYMBOLS <ls_dem> TYPE ty_demanda.

    DATA lt_colunas    TYPE zcl_pc_planilha=>tt_colunas.
    DATA lt_erros      TYPE string_table.
    DATA lt_linhas     TYPE STANDARD TABLE OF ty_linha WITH EMPTY KEY.
    DATA lt_grupos     TYPE STANDARD TABLE OF ty_grupo WITH EMPTY KEY.
    DATA lt_cpfs       TYPE STANDARD TABLE OF zr_pc_cliente-Cpf WITH NON-UNIQUE KEY table_line.
    DATA lt_skus       TYPE STANDARD TABLE OF zr_pc_item-Sku WITH NON-UNIQUE KEY table_line.
    DATA lt_cli_status TYPE SORTED TABLE OF ty_cli_status WITH UNIQUE KEY cpf.
    DATA lt_demanda    TYPE SORTED TABLE OF ty_demanda WITH UNIQUE KEY item_uuid.

    lt_colunas = VALUE #(
      ( campo = c_col-ref        sinonimos = `REFERENCIA|REFERENCIADOPEDIDO|NUMEROPEDIDO|NUMERO|IDPEDIDO|ID|AGRUPADOR` obrigatoria = abap_true )
      ( campo = c_col-cpf        sinonimos = `CPFCLIENTE|CPFDOCLIENTE`                                                obrigatoria = abap_true )
      ( campo = c_col-sku        sinonimos = `CODIGOSKU|CODIGO|ITEM`                                                  obrigatoria = abap_true )
      ( campo = c_col-quantidade sinonimos = `QTDE|QTD|QUANTIDADEITEM`                                                obrigatoria = abap_true )
      ( campo = c_col-obs        sinonimos = `OBS|OBSERVACOES` ) ).

    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lt_erros, lt_linhas, lt_grupos, lt_cpfs, lt_skus, lt_cli_status, lt_demanda.

      IF zcl_pc_auth=>pedido_pode_criar( ) = abap_false.
        APPEND VALUE #( %msg = NEW zcx_pc_msg( textid = zcx_pc_msg=>sem_autorizacao ) ) TO reported-pedido.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-pedido.
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

      " 2) Formato de cada linha
      LOOP AT lt_registros INTO DATA(ls_reg).
        DATA(lv_pref)  = |Linha { ls_reg-linha }: |.
        DATA(lv_antes) = lines( lt_erros ).
        DATA(ls_lin)   = VALUE ty_linha( linha = ls_reg-linha ).

        ls_lin-ref = to_upper( zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-ref ) ).
        IF ls_lin-ref IS INITIAL.
          APPEND |{ lv_pref }Pedido (referência que agrupa os itens) é obrigatório.| TO lt_erros.
        ENDIF.

        DATA(lv_cpf_txt) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-cpf ).
        ls_lin-cpf = zcl_pc_importacao=>normalizar_cpf( lv_cpf_txt ).
        IF zcl_pc_util=>validar_cpf( ls_lin-cpf ) = abap_false.
          APPEND |{ lv_pref }CPF inválido ({ lv_cpf_txt }).| TO lt_erros.
        ENDIF.

        ls_lin-sku = to_upper( zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-sku ) ).
        IF ls_lin-sku IS INITIAL.
          APPEND |{ lv_pref }SKU é obrigatório.| TO lt_erros.
        ENDIF.

        DATA(lv_qtde_txt) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-quantidade ).
        zcl_pc_planilha=>para_inteiro( EXPORTING iv_texto  = lv_qtde_txt
                                       IMPORTING ev_valor  = DATA(lv_qtde)
                                                 ev_valido = DATA(lv_qtde_ok) ).
        IF lv_qtde_ok = abap_false OR lv_qtde <= 0.
          APPEND |{ lv_pref }Quantidade inválida ({ lv_qtde_txt }). Informe um inteiro maior que zero.| TO lt_erros.
        ELSE.
          ls_lin-qtde = lv_qtde.
        ENDIF.

        ls_lin-obs = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-obs ).
        IF strlen( ls_lin-obs ) > 500.
          APPEND |{ lv_pref }Observação excede 500 caracteres.| TO lt_erros.
        ENDIF.

        IF lines( lt_erros ) = lv_antes.
          APPEND ls_lin TO lt_linhas.
        ENDIF.
      ENDLOOP.

      " 3) Cliente, item, consistência do pedido e estoque (nas linhas bem formadas)
      IF lt_linhas IS NOT INITIAL.
        lt_cpfs = VALUE #( FOR l IN lt_linhas ( l-cpf ) ).
        SORT lt_cpfs.
        DELETE ADJACENT DUPLICATES FROM lt_cpfs.
        lt_skus = VALUE #( FOR l IN lt_linhas ( l-sku ) ).
        SORT lt_skus.
        DELETE ADJACENT DUPLICATES FROM lt_skus.

        SELECT ClienteUUID, Cpf, ClienteAtivo
          FROM zr_pc_cliente
          FOR ALL ENTRIES IN @lt_cpfs
          WHERE Cpf = @lt_cpfs-table_line
          INTO TABLE @DATA(lt_clientes).

        SELECT ItemUUID, Sku, ItemAtivo, QtdeEstoque, QtdeReservada
          FROM zr_pc_item
          FOR ALL ENTRIES IN @lt_skus
          WHERE Sku = @lt_skus-table_line
          INTO TABLE @DATA(lt_itens_db).
      ENDIF.

      LOOP AT lt_cpfs INTO DATA(lv_cpf).
        DATA(ls_status) = VALUE ty_cli_status( cpf = lv_cpf ).
        READ TABLE lt_clientes INTO DATA(ls_cli) WITH KEY Cpf = lv_cpf.
        IF sy-subrc <> 0.
          ls_status-motivo = `cliente não encontrado`.
        ELSEIF ls_cli-ClienteAtivo = abap_false.
          ls_status-motivo = `cliente inativo`.
        ELSEIF endereco_principal( ls_cli-ClienteUUID )-endereco_uuid IS INITIAL.
          ls_status-motivo = `cliente sem endereço principal`.
        ELSE.
          ls_status-cliente_uuid = ls_cli-ClienteUUID.
        ENDIF.
        INSERT ls_status INTO TABLE lt_cli_status.
      ENDLOOP.

      LOOP AT lt_linhas ASSIGNING FIELD-SYMBOL(<ls_lin>).
        lv_pref = |Linha { <ls_lin>-linha }: |.

        DATA(ls_cli_st) = lt_cli_status[ cpf = <ls_lin>-cpf ].
        IF ls_cli_st-motivo IS NOT INITIAL.
          APPEND |{ lv_pref }CPF { zcl_pc_util=>formatar_cpf( <ls_lin>-cpf ) }: { ls_cli_st-motivo }.| TO lt_erros.
        ELSE.
          <ls_lin>-cliente_uuid = ls_cli_st-cliente_uuid.
        ENDIF.

        READ TABLE lt_itens_db INTO DATA(ls_it) WITH KEY Sku = <ls_lin>-sku.
        IF sy-subrc <> 0.
          APPEND |{ lv_pref }SKU { <ls_lin>-sku } não encontrado.| TO lt_erros.
        ELSEIF ls_it-ItemAtivo = abap_false.
          APPEND |{ lv_pref }SKU { <ls_lin>-sku } está inativo.| TO lt_erros.
        ELSE.
          <ls_lin>-item_uuid = ls_it-ItemUUID.
        ENDIF.

        " Todas as linhas de um pedido pertencem ao mesmo cliente
        READ TABLE lt_grupos ASSIGNING FIELD-SYMBOL(<ls_grupo>) WITH KEY ref = <ls_lin>-ref.
        IF sy-subrc <> 0.
          APPEND VALUE #( ref          = <ls_lin>-ref
                          linha        = <ls_lin>-linha
                          cpf          = <ls_lin>-cpf
                          cliente_uuid = <ls_lin>-cliente_uuid
                          obs          = <ls_lin>-obs ) TO lt_grupos.
        ELSE.
          IF <ls_grupo>-cpf <> <ls_lin>-cpf.
            APPEND |{ lv_pref }o pedido "{ <ls_lin>-ref }" tem CPFs diferentes (linha { <ls_grupo>-linha } usa { zcl_pc_util=>formatar_cpf( <ls_grupo>-cpf ) }).| TO lt_erros.
          ENDIF.
          IF <ls_grupo>-obs IS INITIAL AND <ls_lin>-obs IS NOT INITIAL.
            <ls_grupo>-obs = <ls_lin>-obs.
          ENDIF.
        ENDIF.
      ENDLOOP.

      " O estoque disponível tem de cobrir o total pedido na planilha inteira
      LOOP AT lt_linhas INTO DATA(ls_lin_est) WHERE item_uuid IS NOT INITIAL.
        READ TABLE lt_demanda ASSIGNING <ls_dem> WITH TABLE KEY item_uuid = ls_lin_est-item_uuid.
        IF sy-subrc <> 0.
          INSERT VALUE #( item_uuid = ls_lin_est-item_uuid ) INTO TABLE lt_demanda ASSIGNING <ls_dem>.
        ENDIF.
        <ls_dem>-solicitado = <ls_dem>-solicitado + ls_lin_est-qtde.

        READ TABLE lt_itens_db INTO DATA(ls_it_est) WITH KEY ItemUUID = ls_lin_est-item_uuid.
        DATA(lv_disponivel) = ls_it_est-QtdeEstoque - ls_it_est-QtdeReservada.
        IF <ls_dem>-solicitado > lv_disponivel.
          APPEND |Linha { ls_lin_est-linha }: estoque insuficiente para o SKU { ls_it_est-Sku } (disponível: { lv_disponivel }; pedido na planilha até aqui: { <ls_dem>-solicitado }).| TO lt_erros.
        ENDIF.
      ENDLOOP.

      IF lt_erros IS NOT INITIAL.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 4) Criação (instâncias ativas): as determinations definem status inicial,
      "    endereço principal, número do pedido e reservam o estoque, igual ao
      "    registro pela tela; as validations rodam no save.
      DATA lt_cria_ped TYPE TABLE FOR CREATE zr_pc_pedido\\Pedido.
      DATA lt_cria_itm TYPE TABLE FOR CREATE zr_pc_pedido\\Pedido\_Itens.
      CLEAR: lt_cria_ped, lt_cria_itm.

      LOOP AT lt_grupos INTO DATA(ls_grupo).
        APPEND VALUE #( %cid        = |PED{ ls_grupo-linha }|
                        ClienteUUID = ls_grupo-cliente_uuid
                        Observacao  = ls_grupo-obs ) TO lt_cria_ped.
        APPEND VALUE #( %cid_ref = |PED{ ls_grupo-linha }|
                        %target  = VALUE #( FOR l IN lt_linhas WHERE ( ref = ls_grupo-ref )
                                            ( %cid           = |ITM{ l-linha }|
                                              ItemUUID       = l-item_uuid
                                              QtdeItemPedido = l-qtde ) ) ) TO lt_cria_itm.
      ENDLOOP.

      CLEAR gt_falhas_registro.

      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido
          CREATE FIELDS ( ClienteUUID Observacao )
          WITH lt_cria_ped
          CREATE BY \_Itens FIELDS ( ItemUUID QtdeItemPedido )
          WITH lt_cria_itm
        MAPPED   DATA(ls_mapped)
        FAILED   DATA(ls_failed)
        REPORTED DATA(ls_reported).

      IF ls_failed-pedido IS NOT INITIAL OR ls_failed-itempedido IS NOT INITIAL.
        APPEND `Não foi possível criar os pedidos.` TO lt_erros.
        LOOP AT ls_reported-pedido INTO DATA(ls_rep_ped) WHERE %msg IS BOUND.
          APPEND |{ linha_do_cid( ls_rep_ped-%cid ) }{ ls_rep_ped-%msg->if_message~get_text( ) }| TO lt_erros.
        ENDLOOP.
        LOOP AT ls_reported-itempedido INTO DATA(ls_rep_itm) WHERE %msg IS BOUND.
          APPEND |{ linha_do_cid( ls_rep_itm-%cid ) }{ ls_rep_itm-%msg->if_message~get_text( ) }| TO lt_erros.
        ENDLOOP.
      ENDIF.

      " A reserva de estoque (determination) não pode falhar o save sozinha:
      " guarda as falhas em GT_FALHAS_REGISTRO. Aqui elas cancelam a importação.
      LOOP AT gt_falhas_registro INTO DATA(ls_falha).
        APPEND ls_falha-msg->if_message~get_text( ) TO lt_erros.
      ENDLOOP.
      CLEAR gt_falhas_registro.

      IF lt_erros IS NOT INITIAL.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 5) Resumo com a faixa de números gerados
      READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido
          FIELDS ( NumeroPedido )
          WITH CORRESPONDING #( ls_mapped-pedido )
        RESULT DATA(lt_criados).
      SORT lt_criados BY NumeroPedido.

      DATA(lv_faixa) = COND string(
        WHEN lt_criados IS INITIAL THEN ``
        WHEN lines( lt_criados ) = 1 THEN | ({ lt_criados[ 1 ]-NumeroPedido })|
        ELSE | ({ lt_criados[ 1 ]-NumeroPedido } a { lt_criados[ lines( lt_criados ) ]-NumeroPedido })| ).

      APPEND VALUE #( %msg = zcx_pc_msg=>texto(
                               iv_texto    = |Importação concluída: { lines( lt_grupos ) } pedido(s) criado(s){ lv_faixa } com { lines( lt_linhas ) } item(ns). Estoque reservado.|
                               iv_severity = if_abap_behv_message=>severity-success ) )
             TO reported-pedido.
    ENDLOOP.
  ENDMETHOD.


  METHOD falhar_importacao.
    APPEND VALUE #( %msg = zcx_pc_msg=>texto(
                             |Importação cancelada: nenhum pedido foi gravado ({ lines( it_erros ) } erro(s)).| ) )
           TO cs_reported-pedido.

    LOOP AT zcl_pc_importacao=>resumir_erros( it_erros ) INTO DATA(lv_erro).
      APPEND VALUE #( %msg = zcx_pc_msg=>texto( lv_erro ) ) TO cs_reported-pedido.
    ENDLOOP.

    APPEND VALUE #( %cid = iv_cid ) TO cs_failed-pedido.
  ENDMETHOD.


  METHOD linha_do_cid.
    DATA(lv_numero) = match( val = iv_cid pcre = `\d+` ).
    rv_texto = COND #( WHEN lv_numero IS NOT INITIAL THEN |Linha { lv_numero }: | ).
  ENDMETHOD.


  METHOD endereco_principal.
    CHECK iv_cliente_uuid IS NOT INITIAL.

    SELECT SINGLE EnderecoUUID, Cep, Logradouro, Numero, Complemento, Bairro, Cidade, Uf
      FROM zr_pc_endereco
      WHERE ClienteUUID       = @iv_cliente_uuid
        AND EnderecoPrincipal = @abap_true
      INTO @DATA(ls_end).

    IF sy-subrc = 0.
      rs_endereco-endereco_uuid = ls_end-EnderecoUUID.
      rs_endereco-completo      = zcl_pc_util=>formatar_endereco( iv_logradouro  = ls_end-Logradouro
                                                                  iv_numero      = ls_end-Numero
                                                                  iv_complemento = ls_end-Complemento
                                                                  iv_bairro      = ls_end-Bairro
                                                                  iv_cidade      = ls_end-Cidade
                                                                  iv_uf          = ls_end-Uf
                                                                  iv_cep         = ls_end-Cep ).
    ENDIF.
  ENDMETHOD.


  METHOD somar_quantidades.
    LOOP AT it_itens INTO DATA(ls_item).
      READ TABLE rt_qtde ASSIGNING FIELD-SYMBOL(<ls_qtde>) WITH TABLE KEY item_uuid = ls_item-ItemUUID.
      IF sy-subrc = 0.
        <ls_qtde>-qtde += ls_item-QtdeItemPedido.
      ELSE.
        INSERT VALUE #( item_uuid = ls_item-ItemUUID qtde = ls_item-QtdeItemPedido ) INTO TABLE rt_qtde.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD registrar_erro.
    IF NOT line_exists( cs_failed-pedido[ PedidoUUID = is_pedido-PedidoUUID ] ).
      APPEND VALUE #( %tky = is_pedido-%tky ) TO cs_failed-pedido.
    ENDIF.
    APPEND VALUE #( %tky = is_pedido-%tky %msg = io_msg ) TO cs_reported-pedido.
  ENDMETHOD.


  METHOD propagar.
    LOOP AT is_reported-pedido INTO DATA(ls_rep) WHERE %msg IS BOUND.
      APPEND ls_rep TO cs_reported-pedido.
    ENDLOOP.
    LOOP AT is_reported-itempedido INTO DATA(ls_rep_item) WHERE %msg IS BOUND.
      APPEND ls_rep_item TO cs_reported-itempedido.
    ENDLOOP.
    LOOP AT is_reported-pagamento INTO DATA(ls_rep_pag) WHERE %msg IS BOUND.
      APPEND ls_rep_pag TO cs_reported-pagamento.
    ENDLOOP.

    APPEND LINES OF is_failed-pedido          TO cs_failed-pedido.
    APPEND LINES OF is_failed-itempedido      TO cs_failed-itempedido.
    APPEND LINES OF is_failed-pagamento       TO cs_failed-pagamento.
    APPEND LINES OF is_failed-clientesnapshot TO cs_failed-clientesnapshot.
    APPEND LINES OF is_failed-itemsnapshot    TO cs_failed-itemsnapshot.
  ENDMETHOD.


  METHOD erro_status.
    ro_msg = SWITCH #( is_pedido-StatusPedido
               WHEN zif_pc_constants=>c_status_pedido-finalizado
                 THEN NEW zcx_pc_msg( textid = zcx_pc_msg=>pedido_finalizado_imutavel )
               WHEN zif_pc_constants=>c_status_pedido-cancelado
                 THEN NEW zcx_pc_msg( textid = zcx_pc_msg=>pedido_cancelado_imutavel )
               ELSE NEW zcx_pc_msg( textid = zcx_pc_msg=>pedido_status_invalido
                                    attr1  = COND string( WHEN is_pedido-%is_draft = if_abap_behv=>mk-on
                                                          THEN `DRAFT`
                                                          ELSE is_pedido-StatusPedido ) ) ).
  ENDMETHOD.


  METHOD ReservarEstoqueRegistro.
    " Uma determination não tem FAILED e não pode abortar o Save: as falhas da
    " reserva ficam em gt_falhas_registro e ValidarRegistro (validation on save
    " do pedido ativo) as converte em FAILED, descartando a gravação.
    DATA ls_failed   TYPE ty_failed.
    DATA ls_reported TYPE ty_reported.

    LOOP AT keys INTO DATA(ls_key).
      DELETE gt_falhas_registro WHERE pedido_uuid = ls_key-PedidoUUID.
    ENDLOOP.

    reservar_registro( EXPORTING it_keys  = VALUE #( FOR k IN keys
                                                     ( is_draft = k-%is_draft pedido_uuid = k-PedidoUUID ) )
                       CHANGING  failed   = ls_failed
                                 reported = ls_reported ).

    LOOP AT ls_reported-pedido INTO DATA(ls_rep) WHERE %msg IS BOUND.
      IF line_exists( ls_failed-pedido[ PedidoUUID = ls_rep-PedidoUUID ] ).
        APPEND VALUE #( pedido_uuid = ls_rep-PedidoUUID msg = ls_rep-%msg ) TO gt_falhas_registro.
      ELSE.
        APPEND VALUE #( %tky = ls_rep-%tky %msg = ls_rep-%msg ) TO reported-pedido.
      ENDIF.
    ENDLOOP.
    LOOP AT ls_failed-pedido INTO DATA(ls_fail)
         WHERE PedidoUUID IS NOT INITIAL.
      IF NOT line_exists( gt_falhas_registro[ pedido_uuid = ls_fail-PedidoUUID ] ).
        APPEND VALUE #( pedido_uuid = ls_fail-PedidoUUID
                        msg         = NEW zcx_pc_msg( textid = zcx_pc_msg=>pedido_status_invalido
                                                      attr1  = `Reserva de estoque` ) ) TO gt_falhas_registro.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD reservar_registro.
    " Roda quando o rascunho é salvo (Save) e o pedido é registrado como
    " instância ativa CRIADO: revalida o essencial, reserva o estoque dos itens
    " (EML no BO Item, sob lock e com releitura), fixa preços e total.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        ALL FIELDS
        WITH VALUE #( FOR k IN it_keys ( %is_draft = k-is_draft PedidoUUID = k-pedido_uuid ) )
      RESULT DATA(lt_pedidos)
      ENTITY Pedido BY \_Itens
        ALL FIELDS
        WITH VALUE #( FOR k IN it_keys ( %is_draft = k-is_draft PedidoUUID = k-pedido_uuid ) )
      RESULT DATA(lt_itens).

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      DATA(lv_erro) = abap_false.

      " 1) Só a instância ativa recém-registrada reserva (rascunho não reserva)
      IF ls_pedido-%is_draft = if_abap_behv=>mk-on
         OR ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-criado.
        CONTINUE.
      ENDIF.

      " 2) Cliente ativo
      SELECT SINGLE ClienteAtivo
        FROM zr_pc_cliente
        WHERE ClienteUUID = @ls_pedido-ClienteUUID
        INTO @DATA(lv_cliente_ativo).
      IF sy-subrc <> 0 OR lv_cliente_ativo = abap_false.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zcx_pc_msg=>cliente_inativo )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        lv_erro = abap_true.
      ENDIF.
      CLEAR lv_cliente_ativo.

      " 3) Endereço pertencente ao cliente e marcado como principal
      DATA(ls_endereco) = endereco_principal( ls_pedido-ClienteUUID ).
      IF ls_endereco-endereco_uuid IS INITIAL.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zcx_pc_msg=>cliente_sem_endereco_principal )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        lv_erro = abap_true.
      ENDIF.

      " 4) Itens ativos e quantidades > 0
      DATA(lt_itens_ped) = VALUE tt_itens_pedido( FOR i IN lt_itens
                                                  WHERE ( PedidoUUID = ls_pedido-PedidoUUID
                                                          AND %is_draft = ls_pedido-%is_draft )
                                                  ( i ) ).
      IF lt_itens_ped IS INITIAL.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zcx_pc_msg=>pedido_sem_itens )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 5) Releitura do estoque atual (dados definitivos do banco, não da UI)
      SELECT ItemUUID, Sku, ItemAtivo, PrecoUnitario, Currency, QtdeEstoque, QtdeReservada
        FROM zr_pc_item
        FOR ALL ENTRIES IN @lt_itens_ped
        WHERE ItemUUID = @lt_itens_ped-ItemUUID
        INTO TABLE @DATA(lt_estoque).

      LOOP AT lt_itens_ped INTO DATA(ls_item_ped).
        READ TABLE lt_estoque INTO DATA(ls_estoque) WITH KEY ItemUUID = ls_item_ped-ItemUUID.
        IF sy-subrc <> 0 OR ls_estoque-ItemAtivo = abap_false.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zcx_pc_msg=>item_inativo
                                                       attr1  = COND string( WHEN sy-subrc = 0 THEN ls_estoque-Sku ELSE `?` ) )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ELSEIF ls_item_ped-QtdeItemPedido <= 0.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zcx_pc_msg=>item_qtde_invalida )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ELSEIF ls_estoque-Currency <> zif_pc_constants=>c_moeda_padrao.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zcx_pc_msg=>valor_invalido attr1 = 'Moeda do item' )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ENDIF.
        CLEAR ls_estoque.
      ENDLOOP.

      " 6) Disponibilidade atual (pré-validação; a definitiva ocorre sob lock no BO Item)
      DATA(lt_qtde) = somar_quantidades( lt_itens_ped ).
      LOOP AT lt_qtde INTO DATA(ls_qtde).
        READ TABLE lt_estoque INTO ls_estoque WITH KEY ItemUUID = ls_qtde-item_uuid.
        IF sy-subrc = 0 AND ls_qtde-qtde > ls_estoque-QtdeEstoque - ls_estoque-QtdeReservada.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zcx_pc_msg=>item_estoque_insuficiente
                                                       attr1  = ls_estoque-Sku
                                                       attr2  = |{ ls_estoque-QtdeEstoque - ls_estoque-QtdeReservada }| )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ENDIF.
      ENDLOOP.

      IF lv_erro = abap_true.
        CONTINUE.
      ENDIF.

      " 9) Reserva de estoque (EML no BO Item, com lock e releitura)
      movimentar_estoque( EXPORTING iv_acao     = c_mov-reservar
                                    is_pedido   = ls_pedido
                                    it_qtde     = lt_qtde
                          IMPORTING ev_ok       = DATA(lv_ok)
                          CHANGING  cs_failed   = failed
                                    cs_reported = reported ).
      IF lv_ok = abap_false.
        CONTINUE.
      ENDIF.

      " 7) Fixa o preço unitário nos itens do pedido / 8) calcula o total
      DATA lt_upd_itens TYPE TABLE FOR UPDATE zr_pc_pedido\\ItemPedido.
      CLEAR lt_upd_itens.
      DATA(lv_total) = CONV zr_pc_pedido-ValorTotal( 0 ).

      LOOP AT lt_itens_ped INTO ls_item_ped.
        READ TABLE lt_estoque INTO ls_estoque WITH KEY ItemUUID = ls_item_ped-ItemUUID.
        DATA(lv_valor_item) = CONV zr_pc_item_pedido-ValorTotal( ls_item_ped-QtdeItemPedido * ls_estoque-PrecoUnitario ).
        lv_total += lv_valor_item.
        APPEND VALUE #( %tky                  = ls_item_ped-%tky
                        PrecoUnitarioSnapshot = ls_estoque-PrecoUnitario
                        Currency              = ls_estoque-Currency
                        ValorTotal            = lv_valor_item
                        %control = VALUE #( PrecoUnitarioSnapshot = if_abap_behv=>mk-on
                                            Currency              = if_abap_behv=>mk-on
                                            ValorTotal            = if_abap_behv=>mk-on ) ) TO lt_upd_itens.
      ENDLOOP.

      " 10) StatusEstoque já recalculado pelo BO Item / 11) novo status
      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY ItemPedido
          UPDATE FROM lt_upd_itens
        ENTITY Pedido
          UPDATE FIELDS ( ValorTotal Currency EnderecoUUID EnderecoPrincipalCompleto )
          WITH VALUE #( ( %tky                      = ls_pedido-%tky
                          ValorTotal                = lv_total
                          Currency                  = zif_pc_constants=>c_moeda_padrao
                          EnderecoUUID              = ls_endereco-endereco_uuid
                          EnderecoPrincipalCompleto = ls_endereco-completo ) )
        FAILED DATA(ls_failed_conf)
        REPORTED DATA(ls_reported_conf).

      propagar( EXPORTING is_failed = ls_failed_conf is_reported = ls_reported_conf
                CHANGING  cs_failed = failed cs_reported = reported ).

      IF line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_pedido-%tky
                      %msg = zcx_pc_msg=>sucesso( textid = zcx_pc_msg=>pedido_confirmado
                                                  attr1  = ls_pedido-NumeroPedido ) ) TO reported-pedido.
    ENDLOOP.

  ENDMETHOD.


  METHOD SimularPagamento.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos)
      ENTITY Pedido BY \_Pagamento
        FIELDS ( PedidoUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pagamentos).

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_pedidos INTO DATA(ls_pedido)
           WITH KEY PedidoUUID = ls_key-PedidoUUID %is_draft = ls_key-%is_draft.
      CHECK sy-subrc = 0.

      IF ls_pedido-%is_draft = if_abap_behv=>mk-on
         OR (     ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-criado
              AND ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-aguardando_pagamento ).
        registrar_erro( EXPORTING is_pedido = ls_pedido io_msg = erro_status( ls_pedido )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " Dados do cartão: somente em memória, nunca persistidos
      DATA(ls_sim) = zcl_pc_pagamento_sim=>simular( VALUE #( metodo   = ls_key-%param-MetodoPagamento
                                                             numero   = ls_key-%param-NumeroCartao
                                                             validade = ls_key-%param-Validade
                                                             cvv      = ls_key-%param-Cvv ) ).

      IF ls_sim-dados_validos = abap_false.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zcx_pc_msg=>cartao_dados_invalidos
                                                     attr1  = ls_sim-erro )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      DATA lv_agora TYPE timestampl.
      GET TIME STAMP FIELD lv_agora.

      " Apenas a última tentativa segura é mantida
      READ TABLE lt_pagamentos INTO DATA(ls_pag)
           WITH KEY PedidoUUID = ls_pedido-PedidoUUID %is_draft = ls_pedido-%is_draft.
      IF sy-subrc = 0.
        MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
          ENTITY Pagamento
            UPDATE FIELDS ( MetodoPagamento StatusPagamento BandeiraCartao Ultimos4DigitosCartao
                            CartaoMascarado CodigoAutorizacao MensagemPagamento DataPagamento )
            WITH VALUE #( ( %tky                  = ls_pag-%tky
                            MetodoPagamento       = ls_sim-metodo
                            StatusPagamento       = ls_sim-status
                            BandeiraCartao        = ls_sim-bandeira
                            Ultimos4DigitosCartao = ls_sim-ultimos4
                            CartaoMascarado       = ls_sim-cartao_mascarado
                            CodigoAutorizacao     = ls_sim-codigo_autorizacao
                            MensagemPagamento     = ls_sim-mensagem
                            DataPagamento         = lv_agora ) )
          FAILED DATA(ls_failed_pag)
          REPORTED DATA(ls_reported_pag).

        propagar( EXPORTING is_failed = ls_failed_pag is_reported = ls_reported_pag
                  CHANGING  cs_failed = failed cs_reported = reported ).
      ELSE.
        MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
          ENTITY Pedido
            CREATE BY \_Pagamento
            FIELDS ( MetodoPagamento StatusPagamento BandeiraCartao Ultimos4DigitosCartao
                     CartaoMascarado CodigoAutorizacao MensagemPagamento DataPagamento )
            WITH VALUE #( ( %tky    = ls_pedido-%tky
                            %target = VALUE #( ( %cid                  = 'PAGAMENTO'
                                                 %is_draft             = ls_pedido-%is_draft
                                                 MetodoPagamento       = ls_sim-metodo
                                                 StatusPagamento       = ls_sim-status
                                                 BandeiraCartao        = ls_sim-bandeira
                                                 Ultimos4DigitosCartao = ls_sim-ultimos4
                                                 CartaoMascarado       = ls_sim-cartao_mascarado
                                                 CodigoAutorizacao     = ls_sim-codigo_autorizacao
                                                 MensagemPagamento     = ls_sim-mensagem
                                                 DataPagamento         = lv_agora ) ) ) )
          FAILED DATA(ls_failed_cre)
          REPORTED DATA(ls_reported_cre).

        propagar( EXPORTING is_failed = ls_failed_cre is_reported = ls_reported_cre
                  CHANGING  cs_failed = failed cs_reported = reported ).
      ENDIF.

      IF line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.
      CLEAR ls_pag.

      DATA(lv_aprovado) = xsdbool( ls_sim-status = zif_pc_constants=>c_status_pagamento-aprovado ).

      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido
          UPDATE FIELDS ( StatusPagamento StatusPedido )
          WITH VALUE #( ( %tky            = ls_pedido-%tky
                          StatusPagamento = ls_sim-status
                          StatusPedido    = COND #( WHEN lv_aprovado = abap_true
                                                    THEN zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                                    ELSE zif_pc_constants=>c_status_pedido-aguardando_pagamento ) ) )
          FAILED DATA(ls_failed_ped)
          REPORTED DATA(ls_reported_ped).

      propagar( EXPORTING is_failed = ls_failed_ped is_reported = ls_reported_ped
                CHANGING  cs_failed = failed cs_reported = reported ).

      " Recusa não é erro técnico: o pedido segue aguardando nova tentativa
      APPEND VALUE #( %tky = ls_pedido-%tky
                      %msg = COND #( WHEN lv_aprovado = abap_true
                                     THEN zcx_pc_msg=>sucesso( zcx_pc_msg=>pagamento_aprovado )
                                     ELSE NEW zcx_pc_msg( textid   = zcx_pc_msg=>pagamento_recusado
                                                          severity = if_abap_behv_message=>severity-warning ) ) )
             TO reported-pedido.
      CLEAR ls_sim.
    ENDLOOP.

    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).

    LOOP AT lt_resultado INTO DATA(ls_res).
      IF NOT line_exists( failed-pedido[ PedidoUUID = ls_res-PedidoUUID ] ).
        APPEND VALUE #( %tky = ls_res-%tky %param = ls_res ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD AprovarPedido.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos)
      ENTITY Pedido BY \_Itens
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      " 1) Status AGUARDANDO_APROVACAO / 2) pagamento aprovado
      IF ls_pedido-%is_draft = if_abap_behv=>mk-off
         AND ls_pedido-StatusPedido = zif_pc_constants=>c_status_pedido-aguardando_pagamento.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zcx_pc_msg=>pedido_pagamento_pendente )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.
      IF ls_pedido-%is_draft = if_abap_behv=>mk-on
         OR ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-aguardando_aprovacao.
        registrar_erro( EXPORTING is_pedido = ls_pedido io_msg = erro_status( ls_pedido )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.
      IF ls_pedido-StatusPagamento <> zif_pc_constants=>c_status_pagamento-aprovado.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zcx_pc_msg=>pedido_pagamento_pendente )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(lt_itens_ped) = VALUE tt_itens_pedido( FOR i IN lt_itens
                                                  WHERE ( PedidoUUID = ls_pedido-PedidoUUID
                                                          AND %is_draft = ls_pedido-%is_draft )
                                                  ( i ) ).
      DATA(lt_qtde) = somar_quantidades( lt_itens_ped ).

      " 3) Estoque reservado correspondente (pré-validação)
      IF lt_qtde IS NOT INITIAL.
        SELECT ItemUUID, Sku, QtdeEstoque, QtdeReservada
          FROM zr_pc_item
          FOR ALL ENTRIES IN @lt_qtde
          WHERE ItemUUID = @lt_qtde-item_uuid
          INTO TABLE @DATA(lt_estoque).
      ENDIF.

      DATA(lv_erro) = abap_false.
      LOOP AT lt_qtde INTO DATA(ls_qtde).
        READ TABLE lt_estoque INTO DATA(ls_estoque) WITH KEY ItemUUID = ls_qtde-item_uuid.
        IF sy-subrc <> 0
           OR ls_estoque-QtdeReservada < ls_qtde-qtde
           OR ls_estoque-QtdeEstoque   < ls_qtde-qtde.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zcx_pc_msg=>item_reserva_inconsistente
                                                       attr1  = ls_estoque-Sku )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ENDIF.
        CLEAR ls_estoque.
      ENDLOOP.
      IF lv_erro = abap_true.
        CONTINUE.
      ENDIF.

      " 4-6) Baixa QtdeEstoque e QtdeReservada + recálculo do StatusEstoque (BO Item)
      movimentar_estoque( EXPORTING iv_acao     = c_mov-baixar
                                    is_pedido   = ls_pedido
                                    it_qtde     = lt_qtde
                          IMPORTING ev_ok       = DATA(lv_ok)
                          CHANGING  cs_failed   = failed
                                    cs_reported = reported ).
      IF lv_ok = abap_false.
        CONTINUE.
      ENDIF.

      " 7) Snapshots de cliente, endereço e itens
      criar_snapshots( EXPORTING is_pedido   = ls_pedido
                                 it_itens    = lt_itens_ped
                                 iv_motivo   = 'FINALIZACAO'
                       CHANGING  cs_failed   = failed
                                 cs_reported = reported ).

      IF line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

      " 8) DataFinalizacao / 9) FINALIZADO
      DATA lv_agora TYPE timestampl.
      GET TIME STAMP FIELD lv_agora.

      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido
          UPDATE FIELDS ( StatusPedido DataFinalizacao )
          WITH VALUE #( ( %tky            = ls_pedido-%tky
                          StatusPedido    = zif_pc_constants=>c_status_pedido-finalizado
                          DataFinalizacao = lv_agora ) )
          FAILED DATA(ls_failed_apr)
          REPORTED DATA(ls_reported_apr).

      propagar( EXPORTING is_failed = ls_failed_apr is_reported = ls_reported_apr
                CHANGING  cs_failed = failed cs_reported = reported ).

      IF line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_pedido-%tky
                      %msg = zcx_pc_msg=>sucesso( textid = zcx_pc_msg=>pedido_finalizado
                                                  attr1  = ls_pedido-NumeroPedido ) ) TO reported-pedido.
    ENDLOOP.

    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).

    LOOP AT lt_resultado INTO DATA(ls_res).
      IF NOT line_exists( failed-pedido[ PedidoUUID = ls_res-PedidoUUID ] ).
        APPEND VALUE #( %tky = ls_res-%tky %param = ls_res ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD CancelarPedido.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos)
      ENTITY Pedido BY \_Itens
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_pedidos INTO DATA(ls_pedido)
           WITH KEY PedidoUUID = ls_key-PedidoUUID %is_draft = ls_key-%is_draft.
      CHECK sy-subrc = 0.

      " 1) Status permite cancelamento?
      IF ls_pedido-%is_draft = if_abap_behv=>mk-on
         OR (     ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-criado
              AND ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-aguardando_pagamento
              AND ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-aguardando_aprovacao ).
        registrar_erro( EXPORTING is_pedido = ls_pedido io_msg = erro_status( ls_pedido )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 2) Motivo obrigatório
      DATA(lv_motivo) = condense( ls_key-%param-MotivoCancelamento ).
      IF lv_motivo IS INITIAL.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zcx_pc_msg=>pedido_motivo_cancel_obrig )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 2b) Pagamento já efetuado: inicia processo de reembolso em vez de
      " cancelar direto. O estoque permanece reservado até a decisão.
      IF ls_pedido-StatusPagamento = zif_pc_constants=>c_status_pagamento-aprovado.
        iniciar_processo_reembolso( EXPORTING is_pedido   = ls_pedido
                                              iv_motivo   = lv_motivo
                                    CHANGING  cs_failed   = failed
                                              cs_reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(lt_itens_ped) = VALUE tt_itens_pedido( FOR i IN lt_itens
                                                  WHERE ( PedidoUUID = ls_pedido-PedidoUUID
                                                          AND %is_draft = ls_pedido-%is_draft )
                                                  ( i ) ).

      " 4) Libera a reserva (feita no registro do pedido, vale para todo status cancelável)
      IF ls_pedido-%is_draft = if_abap_behv=>mk-off.
        movimentar_estoque( EXPORTING iv_acao     = c_mov-liberar
                                      is_pedido   = ls_pedido
                                      it_qtde     = somar_quantidades( lt_itens_ped )
                            IMPORTING ev_ok       = DATA(lv_ok)
                            CHANGING  cs_failed   = failed
                                      cs_reported = reported ).
        IF lv_ok = abap_false.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 3) Snapshots (somente se ainda não existirem)
      criar_snapshots( EXPORTING is_pedido   = ls_pedido
                                 it_itens    = lt_itens_ped
                                 iv_motivo   = 'CANCELAMENTO'
                       CHANGING  cs_failed   = failed
                                 cs_reported = reported ).

      IF line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

      " 6) Motivo, data e usuário / 7) CANCELADO
      DATA lv_agora TYPE timestampl.
      GET TIME STAMP FIELD lv_agora.

      DATA lv_usuario TYPE zr_pc_pedido-CanceladoPor.
      TRY.
          lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
        CATCH cx_abap_context_info_error.
          CLEAR lv_usuario.
      ENDTRY.

      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido
          UPDATE FIELDS ( StatusPedido MotivoCancelamento DataCancelamento CanceladoPor )
          WITH VALUE #( ( %tky               = ls_pedido-%tky
                          StatusPedido       = zif_pc_constants=>c_status_pedido-cancelado
                          MotivoCancelamento = lv_motivo
                          DataCancelamento   = lv_agora
                          CanceladoPor       = lv_usuario ) )
          FAILED DATA(ls_failed_can)
          REPORTED DATA(ls_reported_can).

      propagar( EXPORTING is_failed = ls_failed_can is_reported = ls_reported_can
                CHANGING  cs_failed = failed cs_reported = reported ).

      IF line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_pedido-%tky
                      %msg = zcx_pc_msg=>sucesso( textid = zcx_pc_msg=>pedido_cancelado
                                                  attr1  = ls_pedido-NumeroPedido ) ) TO reported-pedido.
    ENDLOOP.

    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).

    LOOP AT lt_resultado INTO DATA(ls_res).
      IF NOT line_exists( failed-pedido[ PedidoUUID = ls_res-PedidoUUID ] ).
        APPEND VALUE #( %tky = ls_res-%tky %param = ls_res ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD iniciar_processo_reembolso.
    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    DATA lv_usuario TYPE zr_pc_reembolso-SolicitadoPor.
    TRY.
        lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        CLEAR lv_usuario.
    ENDTRY.

    " A solicitação vive no BO Reembolso (root próprio, app Gestão de Reembolsos)
    MODIFY ENTITIES OF zr_pc_reembolso
      ENTITY Reembolso
        CREATE FIELDS ( PedidoUUID NumeroPedido ClienteUUID StatusReembolso StatusPedidoAnterior
                        Currency ValorReembolso MotivoSolicitacao DataSolicitacao SolicitadoPor )
        WITH VALUE #( ( %cid                 = 'REEMBOLSO'
                        PedidoUUID           = is_pedido-PedidoUUID
                        NumeroPedido         = is_pedido-NumeroPedido
                        ClienteUUID          = is_pedido-ClienteUUID
                        StatusReembolso      = zif_pc_constants=>c_status_reembolso-pendente
                        StatusPedidoAnterior = is_pedido-StatusPedido
                        Currency             = is_pedido-Currency
                        ValorReembolso       = is_pedido-ValorTotal
                        MotivoSolicitacao    = iv_motivo
                        DataSolicitacao      = lv_agora
                        SolicitadoPor        = lv_usuario ) )
      FAILED   DATA(ls_failed_reemb)
      REPORTED DATA(ls_reported_reemb).

    LOOP AT ls_reported_reemb-reembolso INTO DATA(ls_rep_reemb) WHERE %msg IS BOUND.
      APPEND VALUE #( %tky = is_pedido-%tky %msg = ls_rep_reemb-%msg ) TO cs_reported-pedido.
    ENDLOOP.
    IF ls_failed_reemb-reembolso IS NOT INITIAL.
      IF NOT line_exists( cs_failed-pedido[ PedidoUUID = is_pedido-PedidoUUID ] ).
        APPEND VALUE #( %tky = is_pedido-%tky ) TO cs_failed-pedido.
      ENDIF.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        UPDATE FIELDS ( StatusPedido MotivoCancelamento )
        WITH VALUE #( ( %tky               = is_pedido-%tky
                        StatusPedido       = zif_pc_constants=>c_status_pedido-processar_reembolso
                        MotivoCancelamento = iv_motivo ) )
      FAILED   DATA(ls_failed_upd)
      REPORTED DATA(ls_reported_upd).

    propagar( EXPORTING is_failed = ls_failed_upd is_reported = ls_reported_upd
              CHANGING  cs_failed = cs_failed cs_reported = cs_reported ).

    IF line_exists( cs_failed-pedido[ PedidoUUID = is_pedido-PedidoUUID ] ).
      RETURN.
    ENDIF.

    APPEND VALUE #( %tky = is_pedido-%tky
                    %msg = zcx_pc_msg=>sucesso( textid = zcx_pc_msg=>pedido_reembolso_solicitado
                                                attr1  = is_pedido-NumeroPedido ) ) TO cs_reported-pedido.
  ENDMETHOD.


  METHOD CancelarPorReembolso.
    " Chamada pelo BO Reembolso (AprovarReembolso) na mesma LUW. A decisão e o
    " status do reembolso são gravados por aquele BO; aqui só o lado do pedido.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos)
      ENTITY Pedido BY \_Itens
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_pedidos INTO DATA(ls_pedido)
           WITH KEY PedidoUUID = ls_key-PedidoUUID %is_draft = ls_key-%is_draft.
      CHECK sy-subrc = 0.

      " 1) Status permite decisão de reembolso?
      IF ls_pedido-%is_draft = if_abap_behv=>mk-on
         OR ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-processar_reembolso.
        registrar_erro( EXPORTING is_pedido = ls_pedido io_msg = erro_status( ls_pedido )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(lt_itens_ped) = VALUE tt_itens_pedido( FOR i IN lt_itens
                                                  WHERE ( PedidoUUID = ls_pedido-PedidoUUID
                                                          AND %is_draft = ls_pedido-%is_draft )
                                                  ( i ) ).

      " 3) Libera a reserva de estoque (o pedido não avança mais)
      IF ls_pedido-%is_draft = if_abap_behv=>mk-off.
        movimentar_estoque( EXPORTING iv_acao     = c_mov-liberar
                                      is_pedido   = ls_pedido
                                      it_qtde     = somar_quantidades( lt_itens_ped )
                            IMPORTING ev_ok       = DATA(lv_ok)
                            CHANGING  cs_failed   = failed
                                      cs_reported = reported ).
        IF lv_ok = abap_false.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 4) Snapshots (somente se ainda não existirem)
      criar_snapshots( EXPORTING is_pedido   = ls_pedido
                                 it_itens    = lt_itens_ped
                                 iv_motivo   = 'CANCELAMENTO'
                       CHANGING  cs_failed   = failed
                                 cs_reported = reported ).

      IF line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

      DATA lv_agora TYPE timestampl.
      GET TIME STAMP FIELD lv_agora.

      DATA lv_usuario TYPE zr_pc_pedido-CanceladoPor.
      TRY.
          lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
        CATCH cx_abap_context_info_error.
          CLEAR lv_usuario.
      ENDTRY.

      " 5) Pedido efetivamente cancelado
      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido
          UPDATE FIELDS ( StatusPedido DataCancelamento CanceladoPor )
          WITH VALUE #( ( %tky             = ls_pedido-%tky
                          StatusPedido     = zif_pc_constants=>c_status_pedido-cancelado
                          DataCancelamento = lv_agora
                          CanceladoPor     = lv_usuario ) )
        FAILED   DATA(ls_failed_apr)
        REPORTED DATA(ls_reported_apr).

      propagar( EXPORTING is_failed = ls_failed_apr is_reported = ls_reported_apr
                CHANGING  cs_failed = failed cs_reported = reported ).

      IF line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

    ENDLOOP.

    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).

    LOOP AT lt_resultado INTO DATA(ls_res).
      IF NOT line_exists( failed-pedido[ PedidoUUID = ls_res-PedidoUUID ] ).
        APPEND VALUE #( %tky = ls_res-%tky %param = ls_res ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD RetomarPedido.
    " Chamada pelo BO Reembolso (RejeitarReembolso) na mesma LUW: o pedido volta
    " ao status em que estava antes da solicitação de reembolso.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos).

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_pedidos INTO DATA(ls_pedido)
           WITH KEY PedidoUUID = ls_key-PedidoUUID %is_draft = ls_key-%is_draft.
      CHECK sy-subrc = 0.

      " 1) Status permite decisão de reembolso?
      IF ls_pedido-%is_draft = if_abap_behv=>mk-on
         OR ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-processar_reembolso.
        registrar_erro( EXPORTING is_pedido = ls_pedido io_msg = erro_status( ls_pedido )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 2) Status anterior à solicitação, informado pelo BO Reembolso
      DATA(lv_status_anterior) = CONV zr_pc_pedido-StatusPedido( condense( ls_key-%param-StatusAnterior ) ).
      IF lv_status_anterior IS INITIAL.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zcx_pc_msg=>campo_obrigatorio
                                                     attr1  = 'Status anterior' )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 3) Pedido volta ao status anterior e o motivo do cancelamento é limpo
      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido
          UPDATE FIELDS ( StatusPedido MotivoCancelamento )
          WITH VALUE #( ( %tky               = ls_pedido-%tky
                          StatusPedido       = lv_status_anterior
                          MotivoCancelamento = '' ) )
        FAILED   DATA(ls_failed_rej)
        REPORTED DATA(ls_reported_rej).

      propagar( EXPORTING is_failed = ls_failed_rej is_reported = ls_reported_rej
                CHANGING  cs_failed = failed cs_reported = reported ).

      IF line_exists( failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

    ENDLOOP.

    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).

    LOOP AT lt_resultado INTO DATA(ls_res).
      IF NOT line_exists( failed-pedido[ PedidoUUID = ls_res-PedidoUUID ] ).
        APPEND VALUE #( %tky = ls_res-%tky %param = ls_res ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD movimentar_estoque.
    DATA ls_failed_item   TYPE RESPONSE FOR FAILED EARLY zr_pc_item.
    DATA ls_reported_item TYPE RESPONSE FOR REPORTED EARLY zr_pc_item.

    ev_ok = abap_true.
    CHECK it_qtde IS NOT INITIAL.

    SELECT ItemUUID, Sku
      FROM zr_pc_item
      FOR ALL ENTRIES IN @it_qtde
      WHERE ItemUUID = @it_qtde-item_uuid
      INTO TABLE @DATA(lt_sku).

    " EML entre BOs: o framework bloqueia cada item (lock master) antes da
    " action; se outro usuário/transação estiver com o item bloqueado, a
    " operação falha e o pedido recebe ITEM_ESTOQUE_CONCORRENTE.
    CASE iv_acao.
      WHEN c_mov-reservar.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE ReservarEstoque
            FROM VALUE #( FOR q IN it_qtde ( ItemUUID = q-item_uuid %param-Quantidade = q-qtde ) )
          FAILED ls_failed_item
          REPORTED ls_reported_item.

      WHEN c_mov-liberar.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE LiberarReserva
            FROM VALUE #( FOR q IN it_qtde ( ItemUUID = q-item_uuid %param-Quantidade = q-qtde ) )
          FAILED ls_failed_item
          REPORTED ls_reported_item.

      WHEN c_mov-baixar.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE BaixarEstoque
            FROM VALUE #( FOR q IN it_qtde ( ItemUUID = q-item_uuid %param-Quantidade = q-qtde ) )
          FAILED ls_failed_item
          REPORTED ls_reported_item.
    ENDCASE.

    " Repassa as mensagens do BO Item para o pedido
    LOOP AT ls_reported_item-item INTO DATA(ls_rep_item) WHERE %msg IS BOUND.
      APPEND VALUE #( %tky = is_pedido-%tky %msg = ls_rep_item-%msg ) TO cs_reported-pedido.
    ENDLOOP.

    IF ls_failed_item-item IS INITIAL.
      RETURN.
    ENDIF.

    ev_ok = abap_false.

    " Falhas sem mensagem própria (ex.: lock) => concorrência
    LOOP AT ls_failed_item-item INTO DATA(ls_fail_item).
      IF NOT line_exists( ls_reported_item-item[ ItemUUID = ls_fail_item-ItemUUID ] ).
        READ TABLE lt_sku INTO DATA(ls_sku) WITH KEY ItemUUID = ls_fail_item-ItemUUID.
        DATA(lv_sku) = COND string( WHEN sy-subrc = 0 THEN ls_sku-Sku ELSE `?` ).
        APPEND VALUE #( %tky = is_pedido-%tky
                        %msg = NEW zcx_pc_msg( textid = zcx_pc_msg=>item_estoque_concorrente
                                               attr1  = lv_sku ) ) TO cs_reported-pedido.
      ENDIF.
    ENDLOOP.

    IF NOT line_exists( cs_failed-pedido[ PedidoUUID = is_pedido-PedidoUUID ] ).
      APPEND VALUE #( %tky = is_pedido-%tky ) TO cs_failed-pedido.
    ENDIF.

    " Compensação: evita reserva parcial - libera o que foi reservado nesta chamada
    IF iv_acao = c_mov-reservar.
      DATA(lt_reservados) = it_qtde.
      LOOP AT ls_failed_item-item INTO ls_fail_item.
        DELETE lt_reservados WHERE item_uuid = ls_fail_item-ItemUUID.
      ENDLOOP.

      IF lt_reservados IS NOT INITIAL.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE LiberarReserva
            FROM VALUE #( FOR r IN lt_reservados ( ItemUUID = r-item_uuid %param-Quantidade = r-qtde ) )
          FAILED DATA(ls_failed_comp)
          REPORTED DATA(ls_reported_comp).

        " A compensação não pode falhar em silêncio: reserva presa é inconsistência
        LOOP AT ls_reported_comp-item INTO DATA(ls_rep_comp) WHERE %msg IS BOUND.
          APPEND VALUE #( %tky = is_pedido-%tky %msg = ls_rep_comp-%msg ) TO cs_reported-pedido.
        ENDLOOP.
        LOOP AT ls_failed_comp-item INTO DATA(ls_fail_comp).
          READ TABLE lt_sku INTO DATA(ls_sku_comp) WITH KEY ItemUUID = ls_fail_comp-ItemUUID.
          APPEND VALUE #( %tky = is_pedido-%tky
                          %msg = NEW zcx_pc_msg(
                                   textid = zcx_pc_msg=>item_reserva_inconsistente
                                   attr1  = COND string( WHEN sy-subrc = 0 THEN ls_sku_comp-Sku ELSE `?` ) ) )
                 TO cs_reported-pedido.
        ENDLOOP.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD criar_snapshots.
    DATA lt_create_itens TYPE TABLE FOR CREATE zr_pc_pedido\\Pedido\_ItensSnapshot.

    " Snapshots são imutáveis e gerados uma única vez
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido BY \_ClienteSnapshot
        FIELDS ( SnapshotUUID ) WITH VALUE #( ( %tky = is_pedido-%tky ) )
      RESULT DATA(lt_snap_cli)
      ENTITY Pedido BY \_ItensSnapshot
        FIELDS ( SnapshotItemUUID ) WITH VALUE #( ( %tky = is_pedido-%tky ) )
      RESULT DATA(lt_snap_itm).

    IF lt_snap_cli IS NOT INITIAL OR lt_snap_itm IS NOT INITIAL.
      APPEND VALUE #( %tky = is_pedido-%tky
                      %msg = NEW zcx_pc_msg( textid   = zcx_pc_msg=>snapshot_existente
                                             severity = if_abap_behv_message=>severity-information ) )
             TO cs_reported-pedido.
      RETURN.
    ENDIF.

    " Dados atuais do cliente e do endereço usado no pedido
    SELECT SINGLE Cpf, Nome, Email, Telefone, Genero, DataNascimento, ClienteAtivo, ScoreCliente
      FROM zr_pc_cliente
      WHERE ClienteUUID = @is_pedido-ClienteUUID
      INTO @DATA(ls_cliente).

    SELECT SINGLE EnderecoUUID, Cep, Logradouro, Numero, Complemento, Bairro, Cidade, Uf, Estado
      FROM zr_pc_endereco
      WHERE EnderecoUUID = @is_pedido-EnderecoUUID
      INTO @DATA(ls_endereco).

    " Dados atuais dos itens
    IF it_itens IS NOT INITIAL.
      SELECT ItemUUID, Sku, Nome, Descricao, Categoria
        FROM zr_pc_item
        FOR ALL ENTRIES IN @it_itens
        WHERE ItemUUID = @it_itens-ItemUUID
        INTO TABLE @DATA(lt_itens_mestre).
    ENDIF.

    APPEND VALUE #( %tky = is_pedido-%tky ) TO lt_create_itens ASSIGNING FIELD-SYMBOL(<ls_create>).
    DATA(lv_seq) = 0.
    LOOP AT it_itens INTO DATA(ls_item).
      lv_seq += 1.
      READ TABLE lt_itens_mestre INTO DATA(ls_mestre) WITH KEY ItemUUID = ls_item-ItemUUID.
      IF sy-subrc <> 0.
        CLEAR ls_mestre.
      ENDIF.
      APPEND VALUE #( %cid           = |SNAP_ITEM_{ lv_seq }|
                      %is_draft      = is_pedido-%is_draft
                      ItemPedidoUUID = ls_item-ItemPedidoUUID
                      ItemUUID       = ls_item-ItemUUID
                      Sku            = ls_mestre-Sku
                      Nome           = ls_mestre-Nome
                      Descricao      = ls_mestre-Descricao
                      Categoria      = ls_mestre-Categoria
                      Quantidade     = ls_item-QtdeItemPedido
                      Currency       = ls_item-Currency
                      PrecoUnitario  = ls_item-PrecoUnitarioSnapshot
                      ValorTotal     = ls_item-ValorTotal ) TO <ls_create>-%target.
    ENDLOOP.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        CREATE BY \_ClienteSnapshot
          FIELDS ( ClienteUUID Cpf Nome Email Telefone Genero DataNascimento ClienteAtivo ScoreCliente
                   EnderecoUUID Cep Logradouro Numero Complemento Bairro Cidade Uf Estado
                   EnderecoCompleto MotivoSnapshot )
          WITH VALUE #( ( %tky    = is_pedido-%tky
                          %target = VALUE #( ( %cid             = 'SNAP_CLIENTE'
                                               %is_draft        = is_pedido-%is_draft
                                               ClienteUUID      = is_pedido-ClienteUUID
                                               Cpf              = ls_cliente-Cpf
                                               Nome             = ls_cliente-Nome
                                               Email            = ls_cliente-Email
                                               Telefone         = ls_cliente-Telefone
                                               Genero           = ls_cliente-Genero
                                               DataNascimento   = ls_cliente-DataNascimento
                                               ClienteAtivo     = ls_cliente-ClienteAtivo
                                               ScoreCliente     = ls_cliente-ScoreCliente
                                               EnderecoUUID     = ls_endereco-EnderecoUUID
                                               Cep              = ls_endereco-Cep
                                               Logradouro       = ls_endereco-Logradouro
                                               Numero           = ls_endereco-Numero
                                               Complemento      = ls_endereco-Complemento
                                               Bairro           = ls_endereco-Bairro
                                               Cidade           = ls_endereco-Cidade
                                               Uf               = ls_endereco-Uf
                                               Estado           = ls_endereco-Estado
                                               EnderecoCompleto = is_pedido-EnderecoPrincipalCompleto
                                               MotivoSnapshot   = iv_motivo ) ) ) )
        CREATE BY \_ItensSnapshot
          FIELDS ( ItemPedidoUUID ItemUUID Sku Nome Descricao Categoria Quantidade Currency
                   PrecoUnitario ValorTotal )
          WITH lt_create_itens
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    propagar( EXPORTING is_failed = ls_failed is_reported = ls_reported
              CHANGING  cs_failed = cs_failed cs_reported = cs_reported ).

    IF ls_failed-pedido IS NOT INITIAL
       OR ls_failed-clientesnapshot IS NOT INITIAL
       OR ls_failed-itemsnapshot IS NOT INITIAL.
      APPEND VALUE #( %tky = is_pedido-%tky ) TO cs_failed-pedido.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


"! Handler da entidade ItemPedido (child)
CLASS lhc_itempedido DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_area,
        item TYPE string VALUE `VALIDAR_ITEM_PEDIDO`,
      END OF c_area.

    METHODS CalcularValorItem FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ItemPedido~CalcularValorItem.

    METHODS ValidarItemPedido FOR VALIDATE ON SAVE
      IMPORTING keys FOR ItemPedido~ValidarItemPedido.

ENDCLASS.


CLASS lhc_itempedido IMPLEMENTATION.

  METHOD CalcularValorItem.
    " Preço provisório (informativo) durante o draft. O preço definitivo é
    " fixado em ConfirmarPedido, a partir da releitura do item no banco.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY ItemPedido
        FIELDS ( PedidoUUID ItemUUID QtdeItemPedido )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    CHECK lt_itens IS NOT INITIAL.

    SELECT ItemUUID, PrecoUnitario, Currency
      FROM zr_pc_item
      FOR ALL ENTRIES IN @lt_itens
      WHERE ItemUUID = @lt_itens-ItemUUID
      INTO TABLE @DATA(lt_precos).

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_pedido\\ItemPedido.
    DATA lt_pais   TYPE TABLE FOR ACTION IMPORT zr_pc_pedido\\Pedido~RecalcularTotal.

    LOOP AT lt_itens INTO DATA(ls_item).
      READ TABLE lt_precos INTO DATA(ls_preco) WITH KEY ItemUUID = ls_item-ItemUUID.
      IF sy-subrc <> 0.
        CLEAR ls_preco.
      ENDIF.

      APPEND VALUE #( %tky                  = ls_item-%tky
                      PrecoUnitarioSnapshot = ls_preco-PrecoUnitario
                      Currency              = COND #( WHEN ls_preco-Currency IS INITIAL
                                                      THEN zif_pc_constants=>c_moeda_padrao
                                                      ELSE ls_preco-Currency )
                      ValorTotal            = ls_item-QtdeItemPedido * ls_preco-PrecoUnitario
                      %control = VALUE #( PrecoUnitarioSnapshot = if_abap_behv=>mk-on
                                          Currency              = if_abap_behv=>mk-on
                                          ValorTotal            = if_abap_behv=>mk-on ) ) TO lt_update.

      IF NOT line_exists( lt_pais[ %is_draft = ls_item-%is_draft PedidoUUID = ls_item-PedidoUUID ] ).
        APPEND VALUE #( %is_draft = ls_item-%is_draft PedidoUUID = ls_item-PedidoUUID ) TO lt_pais.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY ItemPedido UPDATE FROM lt_update
      REPORTED DATA(ls_reported_d3).

    LOOP AT ls_reported_d3-itempedido INTO DATA(ls_rep_d3) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_d3 ) TO reported-itempedido.
    ENDLOOP.

    " Atualiza o total exibido no pedido
    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido EXECUTE RecalcularTotal FROM lt_pais
      REPORTED DATA(ls_reported_d4).

    LOOP AT ls_reported_d4-pedido INTO DATA(ls_rep_d4) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_d4 ) TO reported-pedido.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarItemPedido.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY ItemPedido
        FIELDS ( PedidoUUID ItemUUID QtdeItemPedido )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_itens).

    CHECK lt_itens IS NOT INITIAL.

    SELECT ItemUUID, Sku, ItemAtivo
      FROM zr_pc_item
      FOR ALL ENTRIES IN @lt_itens
      WHERE ItemUUID = @lt_itens-ItemUUID
      INTO TABLE @DATA(lt_mestre).

    LOOP AT lt_itens INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = c_area-item ) TO reported-itempedido.

      DATA lo_msg TYPE REF TO zcx_pc_msg.
      CLEAR lo_msg.

      READ TABLE lt_mestre INTO DATA(ls_mestre) WITH KEY ItemUUID = ls_item-ItemUUID.
      IF ls_item-ItemUUID IS INITIAL.
        lo_msg = NEW #( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Item' ).
      ELSEIF sy-subrc <> 0 OR ls_mestre-ItemAtivo = abap_false.
        lo_msg = NEW #( textid = zcx_pc_msg=>item_inativo attr1 = ls_mestre-Sku ).
      ELSEIF ls_item-QtdeItemPedido <= 0.
        lo_msg = NEW #( textid = zcx_pc_msg=>item_qtde_invalida ).
      ENDIF.
      CLEAR ls_mestre.

      IF lo_msg IS BOUND.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-itempedido.
        APPEND VALUE #( %tky        = ls_item-%tky
                        %state_area = c_area-item
                        %msg        = lo_msg
                        %element-ItemUUID       = if_abap_behv=>mk-on
                        %element-QtdeItemPedido = if_abap_behv=>mk-on
                        %path       = VALUE #( pedido-%is_draft  = ls_item-%is_draft
                                               pedido-PedidoUUID = ls_item-PedidoUUID ) ) TO reported-itempedido.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
