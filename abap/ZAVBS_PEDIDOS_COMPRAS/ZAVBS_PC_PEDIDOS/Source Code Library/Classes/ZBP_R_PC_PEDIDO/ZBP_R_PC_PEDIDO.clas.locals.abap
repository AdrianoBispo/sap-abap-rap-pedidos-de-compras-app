*"* Local Types da behavior pool ZBP_R_PC_PEDIDO

"! <h1>Handler da entidade Pedido (root do BO {@link ZR_PC_PEDIDO})</h1>
"! Registro do pedido com reserva de estoque, ciclo de vida (pagamento,
"! aprovação, cancelamento e reembolso), snapshots e importação por planilha.
"! As ações processam vários pedidos em lote: estoque movimentado numa única
"! chamada ao BO {@link ZR_PC_ITEM} por tipo de movimento
"! ({@link .METH:movimentar_estoque}).
CLASS lhc_pedido DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      "! Tipos de movimento de estoque de {@link .METH:movimentar_estoque}
      BEGIN OF c_mov,
        "! Reserva (ReservarEstoque no BO Item)
        reservar TYPE c LENGTH 1 VALUE 'R',
        "! Liberação da reserva (LiberarReserva no BO Item)
        liberar  TYPE c LENGTH 1 VALUE 'L',
        "! Baixa do estoque reservado (BaixarEstoque no BO Item)
        baixar   TYPE c LENGTH 1 VALUE 'B',
      END OF c_mov.

    CONSTANTS:
      "! State areas das validations (mensagens de estado no rascunho)
      BEGIN OF c_area,
        "! {@link .METH:ValidarCliente}
        cliente  TYPE string VALUE `VALIDAR_CLIENTE`,
        "! {@link .METH:ValidarRegistro}
        registro TYPE string VALUE `VALIDAR_REGISTRO`,
      END OF c_area.

    TYPES:
      "! Chave de um pedido (rascunho ou ativo)
      BEGIN OF ty_pedido_key,
        "! Instância em rascunho ou ativa
        is_draft    TYPE abp_behv_flag,
        "! Pedido
        pedido_uuid TYPE sysuuid_x16,
      END OF ty_pedido_key,
      "! Chaves de pedidos
      tt_pedido_key TYPE STANDARD TABLE OF ty_pedido_key WITH EMPTY KEY.

    TYPES:
      "! Quantidade total de um item (somada entre as linhas do pedido)
      BEGIN OF ty_qtde_item,
        "! Item de estoque
        item_uuid TYPE sysuuid_x16,
        "! Quantidade
        qtde      TYPE i,
      END OF ty_qtde_item,
      "! Quantidades por item (uma linha por item)
      tt_qtde_item TYPE SORTED TABLE OF ty_qtde_item WITH UNIQUE KEY item_uuid.

    "! Linha do pedido lida por READ ENTITIES
    TYPES ts_pedido        TYPE STRUCTURE FOR READ RESULT zr_pc_pedido\\Pedido.
    "! Pedidos lidos por READ ENTITIES
    TYPES tt_pedidos       TYPE TABLE FOR READ RESULT zr_pc_pedido\\Pedido.
    "! Itens dos pedidos lidos pela associação _Itens
    TYPES tt_itens_pedido  TYPE TABLE FOR READ RESULT zr_pc_pedido\\Pedido\_Itens.
    "! FAILED do BO Pedido
    TYPES ty_failed        TYPE RESPONSE FOR FAILED EARLY zr_pc_pedido.
    "! REPORTED do BO Pedido
    TYPES ty_reported      TYPE RESPONSE FOR REPORTED EARLY zr_pc_pedido.
    "! Conjunto de UUIDs (clientes, pedidos ou itens)
    TYPES tt_uuid          TYPE SORTED TABLE OF sysuuid_x16 WITH NON-UNIQUE KEY table_line.
    "! Range de UUIDs (consultas com IN, sem FOR ALL ENTRIES)
    TYPES tt_range_uuid    TYPE RANGE OF sysuuid_x16.

    TYPES:
      "! Endereço principal de um cliente, lido de uma vez para vários clientes
      "! por {@link .METH:enderecos_principais}
      BEGIN OF ty_endereco_cli,
        "! Cliente
        cliente_uuid  TYPE sysuuid_x16,
        "! Endereço marcado como principal
        endereco_uuid TYPE sysuuid_x16,
        "! Endereço formatado ({@link ZCL_PC_UTIL.METH:formatar_endereco})
        completo      TYPE zr_pc_pedido-EnderecoPrincipalCompleto,
      END OF ty_endereco_cli,
      "! Endereço principal por cliente
      tt_endereco_cli TYPE HASHED TABLE OF ty_endereco_cli WITH UNIQUE KEY cliente_uuid.

    TYPES:
      "! Movimento de estoque de um item em um pedido (vários pedidos por chamada)
      BEGIN OF ty_mov_pedido,
        "! Instância do pedido (rascunho ou ativa) que recebe as mensagens
        is_draft    TYPE abp_behv_flag,
        "! Pedido
        pedido_uuid TYPE sysuuid_x16,
        "! Item de estoque
        item_uuid   TYPE sysuuid_x16,
        "! Quantidade do movimento
        qtde        TYPE i,
      END OF ty_mov_pedido,
      "! Movimentos enviados a {@link .METH:movimentar_estoque}
      tt_mov_pedido TYPE STANDARD TABLE OF ty_mov_pedido WITH EMPTY KEY.

    TYPES:
      "! Pedido com o motivo informado (cancelamento / solicitação de reembolso)
      BEGIN OF ty_solicitacao,
        "! Pedido lido
        pedido TYPE ts_pedido,
        "! Motivo informado pelo usuário
        motivo TYPE string,
      END OF ty_solicitacao,
      "! Pedidos a cancelar ou enviar para reembolso
      tt_solicitacao TYPE STANDARD TABLE OF ty_solicitacao WITH EMPTY KEY.

    TYPES:
      "! Falha da reserva de estoque no registro de um pedido
      BEGIN OF ty_falha_registro,
        "! Pedido registrado
        pedido_uuid TYPE sysuuid_x16,
        "! Mensagem da falha
        msg         TYPE REF TO if_abap_behv_message,
      END OF ty_falha_registro.
    "! Falhas da reserva de estoque no registro. Uma determination não tem
    "! FAILED e não aborta o Save; {@link .METH:ValidarRegistro} lê esta tabela na
    "! gravação do pedido recém-registrado e reprova o salvamento com estas mensagens.
    CLASS-DATA gt_falhas_registro TYPE STANDARD TABLE OF ty_falha_registro WITH EMPTY KEY.

    TYPES:
      "! Quantidade de um item já reservada por um pedido
      BEGIN OF ty_reserva_ped,
        "! Pedido
        pedido_uuid TYPE sysuuid_x16,
        "! Item de estoque
        item_uuid   TYPE sysuuid_x16,
        "! Quantidade reservada
        qtde        TYPE i,
      END OF ty_reserva_ped.
    "! Reservas por pedido e item (uma linha por par)
    TYPES tt_reserva_ped TYPE SORTED TABLE OF ty_reserva_ped WITH UNIQUE KEY pedido_uuid item_uuid.
    "! Reserva já aplicada por pedido nesta transação: o banco só muda no Save,
    "! então {@link .METH:reservas_atuais} consulta aqui antes do banco para não
    "! reservar duas vezes.
    CLASS-DATA gt_reserva     TYPE tt_reserva_ped.
    "! Pedidos cuja reserva está em {@link .DATA:gt_reserva} (inclusive sem itens)
    CLASS-DATA gt_reserva_ped TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    "! Quantidade por pedido e item que os pedidos ativos já têm reservada (itens
    "! gravados, ou o que esta transação já aplicou). Uma consulta para todos.
    METHODS reservas_atuais
      IMPORTING it_pedidos         TYPE tt_uuid
      RETURNING VALUE(rt_reservas) TYPE tt_reserva_ped.

    "! Reserva de um pedido, filtrada do resultado de reservas_atuais (memória).
    METHODS reserva_do_pedido
      IMPORTING it_reservas    TYPE tt_reserva_ped
                iv_pedido_uuid TYPE sysuuid_x16
      RETURNING VALUE(rt_qtde) TYPE tt_qtde_item.

    "! Linhas de movimento de estoque dos itens dos pedidos ATIVOS informados.
    METHODS movimentos
      IMPORTING it_pedidos    TYPE tt_pedidos
                it_itens      TYPE tt_itens_pedido
      RETURNING VALUE(rt_mov) TYPE tt_mov_pedido.

    "! Pedidos (entre os informados) que não estão em FAILED.
    METHODS sem_falha
      IMPORTING it_pedidos        TYPE tt_pedidos
                is_failed         TYPE ty_failed
      RETURNING VALUE(rt_pedidos) TYPE tt_pedidos.

    "! Autorização global ({@link ZCL_PC_AUTH}): criar, alterar, excluir e
    "! importar por atividade; ações do ciclo de vida exigem "executar".
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Pedido RESULT result.

    "! Importação em massa por planilha (.xlsx/.csv): uma linha por item, com a
    "! mesma referência para os itens de um pedido. Cria pedidos ativos (ABERTO)
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

    "! Feature control: Edit só em pedido ativo ABERTO, itens só no rascunho e
    "! ações do ciclo de vida só na instância ativa, conforme o status.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Pedido RESULT result.

    "! Pedido novo nasce ABERTO, com pagamento PENDENTE e moeda padrão.
    METHODS DefinirStatusInicial FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Pedido~DefinirStatusInicial.

    "! Ao trocar o cliente, usa o endereço principal atual dele
    "! ({@link .METH:enderecos_principais}, uma consulta para todos).
    METHODS AtualizarEndereco FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Pedido~AtualizarEndereco.

    "! Número do pedido pelo intervalo ZPC_NR / 01 ({@link ZCL_PC_NUMERACAO}),
    "! na fase de interação (o GET NUMBER não pode rodar no save).
    METHODS GerarNumeroPedido FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Pedido~GerarNumeroPedido.

    "! Soma o valor dos itens no total do pedido, ver {@link .METH:recalcular_totais}.
    METHODS CalcularTotalPedido FOR DETERMINE ON SAVE
      IMPORTING keys FOR Pedido~CalcularTotalPedido.

    "! Mantém os indicadores que mostram/escondem as seções da Object Page
    "! (encerrado, sem histórico, não finalizado, não cancelado).
    METHODS AtualizarFlagsStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Pedido~AtualizarFlagsStatus.

    "! Cliente obrigatório e ativo; sem endereço principal gera alerta (status do
    "! cliente e endereços lidos uma vez para todos os pedidos).
    METHODS ValidarCliente FOR VALIDATE ON SAVE
      IMPORTING keys FOR Pedido~ValidarCliente.

    "! Action interna: recalcula o total, ver {@link .METH:recalcular_totais}.
    METHODS RecalcularTotal FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~RecalcularTotal.

    "! Reserva o estoque dos itens quando o rascunho é salvo e o pedido passa
    "! a existir como instância ativa (status ABERTO).
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

    "! Implementação adicional do Activate: antes de o rascunho de edição virar o
    "! pedido ativo, ajusta a reserva de estoque pela diferença entre o que o pedido
    "! já reservou e os itens do rascunho (inclusive itens removidos).
    METHODS Activate FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~Activate.

    "! Efetuar Pagamento: simula o pagamento ({@link ZCL_PC_PAGAMENTO_SIM}),
    "! grava a última tentativa (pagamentos numa única chamada EML) e move o
    "! pedido aprovado para AGUARDANDO_APROVACAO. Parâmetros conferidos em
    "! {@link .METH:precheck_simular_pagamento}.
    METHODS SimularPagamento FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~SimularPagamento RESULT result.

    "! Precheck dos parâmetros de SimularPagamento: método, número do cartão,
    "! validade e CVV são conferidos antes da action (todos os erros de uma vez).
    METHODS precheck_simular_pagamento FOR PRECHECK
      IMPORTING keys FOR ACTION Pedido~SimularPagamento.

    "! Aprovar pedido: confere a reserva, baixa o estoque, gera os snapshots e
    "! finaliza (FINALIZADO). Todos os pedidos em lote.
    METHODS AprovarPedido FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~AprovarPedido RESULT result.

    "! Cancelar pedido (motivo obrigatório): pedido pago vai para reembolso
    "! ({@link .METH:iniciar_processo_reembolso}); os demais liberam a reserva,
    "! geram snapshots e são cancelados. Todos os pedidos em lote.
    METHODS CancelarPedido FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~CancelarPedido RESULT result.

    "! Chamada pelo BO Reembolso ao aprovar o reembolso: libera a reserva,
    "! gera os snapshots e cancela o pedido (PROCESSANDO_REEMBOLSO -> CANCELADO).
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

    "! Endereço principal atual de cada cliente informado (uma única consulta;
    "! cliente sem endereço principal fica fora do resultado).
    METHODS enderecos_principais
      IMPORTING it_clientes         TYPE tt_uuid
      RETURNING VALUE(rt_enderecos) TYPE tt_endereco_cli.

    "! Quantidade total por item (o mesmo item pode estar em mais de uma linha).
    METHODS somar_quantidades
      IMPORTING it_itens       TYPE tt_itens_pedido
      RETURNING VALUE(rt_qtde) TYPE tt_qtde_item.

    "! Executa ReservarEstoque / LiberarReserva / BaixarEstoque no BO Item para
    "! todos os pedidos de uma vez (uma chamada EML, uma linha por item com a
    "! quantidade somada; mesma LUW). Item recusado faz falhar todos os pedidos
    "! que o usam; na reserva, a parte já reservada desses pedidos é liberada
    "! (compensação). Devolve os pedidos que falharam.
    METHODS movimentar_estoque
      IMPORTING iv_acao     TYPE c
                it_mov      TYPE tt_mov_pedido
      EXPORTING et_falhou   TYPE tt_pedido_key
      CHANGING  cs_failed   TYPE ty_failed
                cs_reported TYPE ty_reported.

    "! Pagamento já efetuado: em vez de cancelar direto, cria a solicitação
    "! de reembolso (PENDENTE) e move o pedido para PROCESSANDO_REEMBOLSO.
    "! O estoque permanece reservado até a decisão (AprovarReembolso/RejeitarReembolso).
    "! Todas as solicitações numa única chamada EML por BO.
    METHODS iniciar_processo_reembolso
      IMPORTING it_solicitacoes TYPE tt_solicitacao
      CHANGING  cs_failed       TYPE ty_failed
                cs_reported     TYPE ty_reported.

    "! Congela cliente, endereço e itens no encerramento dos pedidos (uma
    "! consulta por tabela e uma única criação EML para todos os pedidos).
    METHODS criar_snapshots
      IMPORTING it_pedidos  TYPE tt_pedidos
                it_itens    TYPE tt_itens_pedido
                iv_motivo   TYPE csequence
      CHANGING  cs_failed   TYPE ty_failed
                cs_reported TYPE ty_reported.

    "! Marca o pedido como falho (uma vez) e reporta a mensagem nele.
    "! @parameter is_pedido | Pedido com erro
    "! @parameter io_msg | Mensagem ({@link ZCX_PC_MSG})
    "! @parameter cs_failed | FAILED da operação
    "! @parameter cs_reported | REPORTED da operação
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

    "! Mensagem de status que não permite a ação: finalizado (017), cancelado
    "! (018) ou transição inválida com o status atual (015).
    "! @parameter is_pedido | Pedido avaliado
    "! @parameter ro_msg | Mensagem correspondente ao status
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
          l_aberto     = xsdbool( p-StatusPedido = zif_pc_constants=>c_status_pedido-aberto )
          l_ag_apr     = xsdbool( p-StatusPedido = zif_pc_constants=>c_status_pedido-aguardando_aprovacao )
          l_on         = if_abap_behv=>fc-o-enabled
          l_off        = if_abap_behv=>fc-o-disabled
      IN
      ( %tky                     = p-%tky
        " Pedido ABERTO: só os itens podem ser alterados (Edit + Save), o cliente
        " não. O pedido ativo não é excluído, só cancelado; itens só entram no rascunho.
        %delete                  = COND #( WHEN l_ativo = abap_false THEN l_on ELSE l_off )
        %action-Edit             = COND #( WHEN l_ativo = abap_true AND l_aberto = abap_true THEN l_on ELSE l_off )
        %assoc-_Itens            = COND #( WHEN l_ativo = abap_false THEN l_on ELSE l_off )
        " Ações do ciclo de vida somente sobre a instância ativa (não em draft)
        %action-SimularPagamento = COND #( WHEN l_ativo = abap_true AND l_aberto = abap_true
                                           THEN l_on ELSE l_off )
        %action-AprovarPedido    = COND #( WHEN l_ativo = abap_true AND l_ag_apr = abap_true THEN l_on ELSE l_off )
        %action-CancelarPedido   = COND #( WHEN l_ativo = abap_true
                                            AND ( l_aberto = abap_true OR l_ag_apr = abap_true )
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

    " ValorTotal não é inicializado aqui: no create com itens no mesmo request,
    " CalcularValorItem (linha) pode rodar antes e já ter gravado o total.
    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        UPDATE FIELDS ( StatusPedido StatusPagamento Currency )
        WITH VALUE #( FOR p IN lt_pedidos
                      ( %tky            = p-%tky
                        StatusPedido    = zif_pc_constants=>c_status_pedido-aberto
                        StatusPagamento = zif_pc_constants=>c_status_pagamento-pendente
                        Currency        = zif_pc_constants=>c_moeda_padrao ) )
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

    CHECK lt_pedidos IS NOT INITIAL.

    " Endereços principais de todos os clientes numa única consulta
    DATA(lt_enderecos) = enderecos_principais( VALUE #( FOR p IN lt_pedidos ( p-ClienteUUID ) ) ).

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.
    lt_update = VALUE #( FOR p IN lt_pedidos
                         LET e = VALUE ty_endereco_cli( lt_enderecos[ cliente_uuid = p-ClienteUUID ] OPTIONAL )
                         IN ( %tky                      = p-%tky
                              EnderecoUUID              = e-endereco_uuid
                              EnderecoPrincipalCompleto = e-completo
                              %control = VALUE #( EnderecoUUID              = if_abap_behv=>mk-on
                                                  EnderecoPrincipalCompleto = if_abap_behv=>mk-on ) ) ).

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
                          %msg = NEW zcx_pc_msg( textid   = zif_pc_msg=>numeracao_erro
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
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>item_sem_estoque
                                               attr1  = ls_estoque-Sku ) ) TO reported-itempedido.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD AtualizarFlagsStatus.
    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        FIELDS ( StatusPedido PedidoEncerrado PedidoAtivoSemHistorico PedidoNaoFinalizado PedidoNaoCancelado )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_pedidos).

    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      " Encerrado (finalizado ou cancelado): dados do cliente e itens vêm dos
      " snapshots. Nos demais status (aberto, aguardando aprovação, processando
      " reembolso) vêm das tabelas principais. Os indicadores "não finalizado" e
      " "não cancelado" escondem as seções Finalização e Cancelamento.
      DATA(lv_encerrado) = xsdbool( ls_pedido-StatusPedido = zif_pc_constants=>c_status_pedido-finalizado
                                 OR ls_pedido-StatusPedido = zif_pc_constants=>c_status_pedido-cancelado ).
      DATA(lv_ativo_sh)  = xsdbool( lv_encerrado = abap_false ).
      DATA(lv_nao_fin)   = xsdbool( ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-finalizado ).
      DATA(lv_nao_canc)  = xsdbool( ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-cancelado ).

      IF lv_encerrado <> ls_pedido-PedidoEncerrado OR lv_ativo_sh <> ls_pedido-PedidoAtivoSemHistorico
         OR lv_nao_fin <> ls_pedido-PedidoNaoFinalizado OR lv_nao_canc <> ls_pedido-PedidoNaoCancelado.
        APPEND VALUE #( %tky                    = ls_pedido-%tky
                        PedidoEncerrado         = lv_encerrado
                        PedidoAtivoSemHistorico = lv_ativo_sh
                        PedidoNaoFinalizado     = lv_nao_fin
                        PedidoNaoCancelado      = lv_nao_canc
                        %control = VALUE #( PedidoEncerrado         = if_abap_behv=>mk-on
                                            PedidoAtivoSemHistorico = if_abap_behv=>mk-on
                                            PedidoNaoFinalizado     = if_abap_behv=>mk-on
                                            PedidoNaoCancelado      = if_abap_behv=>mk-on ) ) TO lt_update.
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

    " Situação e endereço principal de todos os clientes: uma consulta cada
    DATA(lt_ids_cli) = VALUE tt_uuid( FOR p IN lt_pedidos WHERE ( ClienteUUID IS NOT INITIAL ) ( p-ClienteUUID ) ).
    IF lt_ids_cli IS NOT INITIAL.
      SELECT ClienteUUID, ClienteAtivo
        FROM zr_pc_cliente
        FOR ALL ENTRIES IN @lt_ids_cli
        WHERE ClienteUUID = @lt_ids_cli-table_line
        INTO TABLE @DATA(lt_clientes).
    ENDIF.
    DATA(lt_enderecos) = enderecos_principais( lt_ids_cli ).

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-cliente ) TO reported-pedido.

      IF ls_pedido-ClienteUUID IS INITIAL.
        APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-cliente
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>campo_obrigatorio attr1 = 'Cliente' )
                        %element-ClienteUUID = if_abap_behv=>mk-on ) TO reported-pedido.
        CONTINUE.
      ENDIF.

      READ TABLE lt_clientes INTO DATA(ls_cliente) WITH KEY ClienteUUID = ls_pedido-ClienteUUID.

      IF sy-subrc <> 0 OR ls_cliente-ClienteAtivo = abap_false.
        APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-cliente
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>cliente_inativo )
                        %element-ClienteUUID = if_abap_behv=>mk-on ) TO reported-pedido.
        CONTINUE.
      ENDIF.

      " Sem endereço principal: apenas alerta no salvamento; a confirmação é bloqueada
      IF NOT line_exists( lt_enderecos[ cliente_uuid = ls_pedido-ClienteUUID ] ).
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-cliente
                        %msg = NEW zcx_pc_msg( textid   = zif_pc_msg=>cliente_sem_endereco_principal
                                               severity = if_abap_behv_message=>severity-warning )
                        %element-ClienteUUID = if_abap_behv=>mk-on ) TO reported-pedido.
      ENDIF.
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

    " Dados de apoio dos rascunhos lidos uma única vez (fora do laço): endereço
    " principal dos clientes, reserva já feita por pedido em edição e estoque
    DATA(lt_rascunhos) = VALUE tt_pedidos( FOR p IN lt_pedidos WHERE ( %is_draft = if_abap_behv=>mk-on ) ( p ) ).
    DATA(lt_enderecos) = enderecos_principais( VALUE #( FOR r IN lt_rascunhos WHERE ( ClienteUUID IS NOT INITIAL )
                                                        ( r-ClienteUUID ) ) ).
    DATA(lt_reservas)  = reservas_atuais( VALUE #( FOR r IN lt_rascunhos ( r-PedidoUUID ) ) ).

    DATA(lt_itens_rasc) = VALUE tt_itens_pedido( FOR i IN lt_itens
                                                 WHERE ( %is_draft = if_abap_behv=>mk-on AND ItemUUID IS NOT INITIAL )
                                                 ( i ) ).
    IF lt_itens_rasc IS NOT INITIAL.
      SELECT ItemUUID, Sku, QtdeEstoque, QtdeReservada
        FROM zr_pc_item
        FOR ALL ENTRIES IN @lt_itens_rasc
        WHERE ItemUUID = @lt_itens_rasc-ItemUUID
        INTO TABLE @DATA(lt_estoque).
    ENDIF.

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
         AND NOT line_exists( lt_enderecos[ cliente_uuid = ls_pedido-ClienteUUID ] ).
        APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-registro
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>cliente_sem_endereco_principal )
                        %element-ClienteUUID = if_abap_behv=>mk-on ) TO reported-pedido.
      ENDIF.

      DATA(lt_itens_ped) = VALUE tt_itens_pedido( FOR i IN lt_itens
                                                  WHERE ( PedidoUUID = ls_pedido-PedidoUUID
                                                          AND %is_draft = ls_pedido-%is_draft )
                                                  ( i ) ).
      IF lt_itens_ped IS INITIAL.
        APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-registro
                        %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>pedido_sem_itens ) ) TO reported-pedido.
        CONTINUE.
      ENDIF.

      DATA(lt_qtde) = somar_quantidades( lt_itens_ped ).
      " Pedido aberto em edição: o que ele já reservou continua disponível para ele
      DATA(lt_velho) = reserva_do_pedido( it_reservas = lt_reservas iv_pedido_uuid = ls_pedido-PedidoUUID ).

      LOOP AT lt_qtde INTO DATA(ls_qtde) WHERE item_uuid IS NOT INITIAL.
        READ TABLE lt_estoque INTO DATA(ls_estoque) WITH KEY ItemUUID = ls_qtde-item_uuid.
        IF sy-subrc = 0.
          DATA(lv_proprio) = 0.
          READ TABLE lt_velho INTO DATA(ls_proprio) WITH TABLE KEY item_uuid = ls_qtde-item_uuid.
          IF sy-subrc = 0.
            lv_proprio = ls_proprio-qtde.
          ENDIF.
          DATA(lv_livre) = ls_estoque-QtdeEstoque - ls_estoque-QtdeReservada + lv_proprio.
          IF ls_qtde-qtde > lv_livre.
            APPEND VALUE #( %tky = ls_pedido-%tky ) TO failed-pedido.
            APPEND VALUE #( %tky = ls_pedido-%tky %state_area = c_area-registro
                            %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>item_estoque_insuficiente
                                                   attr1  = ls_estoque-Sku
                                                   attr2  = |{ lv_livre }| ) )
                   TO reported-pedido.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD Activate.
    " Só edição: pedido já reservado. O registro inicial é feito por ReservarEstoqueRegistro.
    " Reservas, rascunhos e estoque são lidos uma vez para todos os pedidos e o
    " estoque é movimentado numa única chamada por tipo de movimento.
    DATA(lt_reservas) = reservas_atuais( VALUE #( FOR k IN keys ( k-PedidoUUID ) ) ).
    CHECK lt_reservas IS NOT INITIAL.

    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        ALL FIELDS
        WITH VALUE #( FOR k IN keys ( %is_draft = if_abap_behv=>mk-on PedidoUUID = k-PedidoUUID ) )
      RESULT DATA(lt_ped)
      ENTITY Pedido BY \_Itens
        ALL FIELDS
        WITH VALUE #( FOR k IN keys ( %is_draft = if_abap_behv=>mk-on PedidoUUID = k-PedidoUUID ) )
      RESULT DATA(lt_itens_rasc).
    CHECK lt_ped IS NOT INITIAL.

    IF lt_itens_rasc IS NOT INITIAL.
      SELECT ItemUUID, Sku, QtdeEstoque, QtdeReservada
        FROM zr_pc_item
        FOR ALL ENTRIES IN @lt_itens_rasc
        WHERE ItemUUID = @lt_itens_rasc-ItemUUID
        INTO TABLE @DATA(lt_estoque).
    ENDIF.

    DATA lt_mov_reservar TYPE tt_mov_pedido.
    DATA lt_mov_liberar  TYPE tt_mov_pedido.
    DATA lt_nova_reserva TYPE tt_reserva_ped.
    DATA lt_reservar     TYPE tt_qtde_item.
    DATA lt_liberar      TYPE tt_qtde_item.
    DATA lv_antes        TYPE i.

    LOOP AT lt_ped INTO DATA(ls_pedido).
      DATA(lt_velho) = reserva_do_pedido( it_reservas = lt_reservas iv_pedido_uuid = ls_pedido-PedidoUUID ).
      CHECK lt_velho IS NOT INITIAL.

      DATA(lt_qtde) = somar_quantidades( VALUE tt_itens_pedido( FOR r IN lt_itens_rasc
                                                                WHERE ( PedidoUUID = ls_pedido-PedidoUUID )
                                                                ( r ) ) ).
      CLEAR: lt_reservar, lt_liberar.
      LOOP AT lt_qtde INTO DATA(ls_novo).
        CLEAR lv_antes.
        READ TABLE lt_velho INTO DATA(ls_antes) WITH TABLE KEY item_uuid = ls_novo-item_uuid.
        IF sy-subrc = 0.
          lv_antes = ls_antes-qtde.
        ENDIF.
        IF ls_novo-qtde > lv_antes.
          INSERT VALUE #( item_uuid = ls_novo-item_uuid qtde = ls_novo-qtde - lv_antes ) INTO TABLE lt_reservar.
        ELSEIF ls_novo-qtde < lv_antes.
          INSERT VALUE #( item_uuid = ls_novo-item_uuid qtde = lv_antes - ls_novo-qtde ) INTO TABLE lt_liberar.
        ENDIF.
      ENDLOOP.
      LOOP AT lt_velho INTO DATA(ls_removido).
        IF NOT line_exists( lt_qtde[ item_uuid = ls_removido-item_uuid ] ).
          INSERT VALUE #( item_uuid = ls_removido-item_uuid qtde = ls_removido-qtde ) INTO TABLE lt_liberar.
        ENDIF.
      ENDLOOP.
      CHECK lt_reservar IS NOT INITIAL OR lt_liberar IS NOT INITIAL.

      " Disponibilidade do que precisa ser reservado a mais (estoque lido antes do laço)
      DATA(lv_erro) = abap_false.
      LOOP AT lt_reservar INTO DATA(ls_a_reservar).
        READ TABLE lt_estoque INTO DATA(ls_estoque) WITH KEY ItemUUID = ls_a_reservar-item_uuid.
        IF sy-subrc = 0 AND ls_a_reservar-qtde > ls_estoque-QtdeEstoque - ls_estoque-QtdeReservada.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zif_pc_msg=>item_estoque_insuficiente
                                                       attr1  = ls_estoque-Sku
                                                       attr2  = |{ ls_estoque-QtdeEstoque - ls_estoque-QtdeReservada }| )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ENDIF.
      ENDLOOP.
      CHECK lv_erro = abap_false.

      " Movimentos acumulados para uma única chamada ao BO Item
      lt_mov_liberar  = VALUE #( BASE lt_mov_liberar FOR l IN lt_liberar
                                 ( is_draft = ls_pedido-%is_draft pedido_uuid = ls_pedido-PedidoUUID
                                   item_uuid = l-item_uuid qtde = l-qtde ) ).
      lt_mov_reservar = VALUE #( BASE lt_mov_reservar FOR x IN lt_reservar
                                 ( is_draft = ls_pedido-%is_draft pedido_uuid = ls_pedido-PedidoUUID
                                   item_uuid = x-item_uuid qtde = x-qtde ) ).
      lt_nova_reserva = VALUE #( BASE lt_nova_reserva FOR q IN lt_qtde
                                 ( pedido_uuid = ls_pedido-PedidoUUID item_uuid = q-item_uuid qtde = q-qtde ) ).
    ENDLOOP.

    " Libera o que sobrou e reserva o que faltou (pedido que falhou na liberação não reserva)
    movimentar_estoque( EXPORTING iv_acao     = c_mov-liberar
                                  it_mov      = lt_mov_liberar
                        IMPORTING et_falhou   = DATA(lt_falhou_lib)
                        CHANGING  cs_failed   = failed
                                  cs_reported = reported ).
    LOOP AT lt_falhou_lib INTO DATA(ls_falhou).
      DELETE lt_mov_reservar WHERE pedido_uuid = ls_falhou-pedido_uuid.
    ENDLOOP.

    movimentar_estoque( EXPORTING iv_acao     = c_mov-reservar
                                  it_mov      = lt_mov_reservar
                        IMPORTING et_falhou   = DATA(lt_falhou_res)
                        CHANGING  cs_failed   = failed
                                  cs_reported = reported ).

    " Registra a reserva aplicada dos pedidos bem-sucedidos: ReservarEstoqueRegistro,
    " se disparar depois, só vê diferença zero
    LOOP AT lt_nova_reserva INTO DATA(ls_nova) GROUP BY ls_nova-pedido_uuid INTO DATA(lv_pedido).
      CHECK NOT line_exists( lt_falhou_lib[ pedido_uuid = lv_pedido ] )
        AND NOT line_exists( lt_falhou_res[ pedido_uuid = lv_pedido ] )
        AND NOT line_exists( failed-pedido[ PedidoUUID = lv_pedido ] ).
      DELETE gt_reserva WHERE pedido_uuid = lv_pedido.
      INSERT LINES OF VALUE tt_reserva_ped( FOR m IN GROUP lv_pedido ( m ) ) INTO TABLE gt_reserva.
      INSERT lv_pedido INTO TABLE gt_reserva_ped.
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
    TYPES:
      BEGIN OF ty_ref,
        cliente_uuid TYPE sysuuid_x16,
        ref          TYPE zr_pc_pedido-ReferenciaImportacao,
      END OF ty_ref.

    CONSTANTS:
      BEGIN OF c_col,
        ref        TYPE string VALUE `Pedido`,
        cpf        TYPE string VALUE `CPF`,
        sku        TYPE string VALUE `SKU`,
        quantidade TYPE string VALUE `Quantidade`,
        obs        TYPE string VALUE `Observação`,
      END OF c_col.

    FIELD-SYMBOLS <ls_dem> TYPE ty_demanda.

    DATA lt_colunas    TYPE zif_pc_planilha=>tt_colunas.
    DATA lt_erros      TYPE string_table.
    DATA lt_linhas     TYPE STANDARD TABLE OF ty_linha WITH EMPTY KEY.
    DATA lt_grupos     TYPE STANDARD TABLE OF ty_grupo WITH EMPTY KEY.
    DATA lt_cpfs       TYPE STANDARD TABLE OF zr_pc_cliente-Cpf WITH NON-UNIQUE KEY table_line.
    DATA lt_skus       TYPE STANDARD TABLE OF zr_pc_item-Sku WITH NON-UNIQUE KEY table_line.
    DATA lt_cli_status TYPE SORTED TABLE OF ty_cli_status WITH UNIQUE KEY cpf.
    DATA lt_demanda    TYPE SORTED TABLE OF ty_demanda WITH UNIQUE KEY item_uuid.
    DATA lt_refs       TYPE STANDARD TABLE OF ty_ref WITH EMPTY KEY.

    lt_colunas = VALUE #(
      ( campo = c_col-ref        sinonimos = `REFERENCIA|REFERENCIADOPEDIDO|NUMEROPEDIDO|NUMERO|IDPEDIDO|ID|AGRUPADOR` obrigatoria = abap_true )
      ( campo = c_col-cpf        sinonimos = `CPFCLIENTE|CPFDOCLIENTE`                                                obrigatoria = abap_true )
      ( campo = c_col-sku        sinonimos = `CODIGOSKU|CODIGO|ITEM`                                                  obrigatoria = abap_true )
      ( campo = c_col-quantidade sinonimos = `QTDE|QTD|QUANTIDADEITEM`                                                obrigatoria = abap_true )
      ( campo = c_col-obs        sinonimos = `OBS|OBSERVACOES` ) ).

    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lt_erros, lt_linhas, lt_grupos, lt_cpfs, lt_skus, lt_cli_status, lt_demanda, lt_refs.

      IF zcl_pc_auth=>pedido_pode_criar( ) = abap_false.
        APPEND VALUE #( %msg = NEW zcx_pc_msg( textid = zif_pc_msg=>sem_autorizacao ) ) TO reported-pedido.
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
        ELSEIF strlen( ls_lin-ref ) > 40.
          APPEND |{ lv_pref }Pedido (referência) excede 40 caracteres.| TO lt_erros.
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

      " Endereço principal dos clientes da planilha: uma única consulta
      DATA(lt_end_cli) = enderecos_principais( VALUE #( FOR c IN lt_clientes ( c-ClienteUUID ) ) ).

      LOOP AT lt_cpfs INTO DATA(lv_cpf).
        DATA(ls_status) = VALUE ty_cli_status( cpf = lv_cpf ).
        READ TABLE lt_clientes INTO DATA(ls_cli) WITH KEY Cpf = lv_cpf.
        IF sy-subrc <> 0.
          ls_status-motivo = `cliente não encontrado`.
        ELSEIF ls_cli-ClienteAtivo = abap_false.
          ls_status-motivo = `cliente inativo`.
        ELSEIF NOT line_exists( lt_end_cli[ cliente_uuid = ls_cli-ClienteUUID ] ).
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

      " A referência (coluna Pedido) é a chave de idempotência da importação:
      " recusada se o cliente já tem pedido não cancelado com ela, para que
      " reenviar a mesma planilha não duplique pedidos
      lt_refs = VALUE #( FOR g IN lt_grupos WHERE ( cliente_uuid IS NOT INITIAL )
                         ( cliente_uuid = g-cliente_uuid ref = g-ref ) ).
      IF lt_refs IS NOT INITIAL.
        SELECT ClienteUUID, ReferenciaImportacao, NumeroPedido
          FROM zr_pc_pedido
          FOR ALL ENTRIES IN @lt_refs
          WHERE ClienteUUID          =  @lt_refs-cliente_uuid
            AND ReferenciaImportacao =  @lt_refs-ref
            AND StatusPedido         <> @zif_pc_constants=>c_status_pedido-cancelado
          INTO TABLE @DATA(lt_ja_importados).
        LOOP AT lt_grupos INTO DATA(ls_grp_dup) WHERE cliente_uuid IS NOT INITIAL.
          READ TABLE lt_ja_importados INTO DATA(ls_dup)
               WITH KEY ClienteUUID = ls_grp_dup-cliente_uuid ReferenciaImportacao = ls_grp_dup-ref.
          IF sy-subrc = 0.
            APPEND |Linha { ls_grp_dup-linha }: o pedido { ls_grp_dup-ref } do cliente { zcl_pc_util=>formatar_cpf( ls_grp_dup-cpf ) } já foi importado (pedido { ls_dup-NumeroPedido }).| TO lt_erros.
          ENDIF.
        ENDLOOP.
      ENDIF.

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
        APPEND VALUE #( %cid                 = |PED{ ls_grupo-linha }|
                        ClienteUUID          = ls_grupo-cliente_uuid
                        Observacao           = ls_grupo-obs
                        ReferenciaImportacao = ls_grupo-ref ) TO lt_cria_ped.
        APPEND VALUE #( %cid_ref = |PED{ ls_grupo-linha }|
                        %target  = VALUE #( FOR l IN lt_linhas WHERE ( ref = ls_grupo-ref )
                                            ( %cid           = |ITM{ l-linha }|
                                              ItemUUID       = l-item_uuid
                                              QtdeItemPedido = l-qtde ) ) ) TO lt_cria_itm.
      ENDLOOP.

      CLEAR gt_falhas_registro.

      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido
          CREATE FIELDS ( ClienteUUID Observacao ReferenciaImportacao )
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


  METHOD enderecos_principais.
    CHECK it_clientes IS NOT INITIAL.

    SELECT ClienteUUID, EnderecoUUID, Cep, Logradouro, Numero, Complemento, Bairro, Cidade, Uf
      FROM zr_pc_endereco
      FOR ALL ENTRIES IN @it_clientes
      WHERE ClienteUUID       = @it_clientes-table_line
        AND EnderecoPrincipal = @abap_true
      INTO TABLE @DATA(lt_end).

    " Um principal por cliente (garantido por DefinirEnderecoPrincipal); um
    " eventual segundo registro do mesmo cliente é ignorado pelo INSERT
    LOOP AT lt_end INTO DATA(ls_end).
      INSERT VALUE #( cliente_uuid  = ls_end-ClienteUUID
                      endereco_uuid = ls_end-EnderecoUUID
                      completo      = zcl_pc_util=>formatar_endereco( iv_logradouro  = ls_end-Logradouro
                                                                      iv_numero      = ls_end-Numero
                                                                      iv_complemento = ls_end-Complemento
                                                                      iv_bairro      = ls_end-Bairro
                                                                      iv_cidade      = ls_end-Cidade
                                                                      iv_uf          = ls_end-Uf
                                                                      iv_cep         = ls_end-Cep ) ) INTO TABLE rt_enderecos.
    ENDLOOP.
  ENDMETHOD.


  METHOD reservas_atuais.
    CHECK it_pedidos IS NOT INITIAL.

    " Pedidos cuja reserva esta transação já aplicou: vale o que está em memória
    DATA(lt_range) = VALUE tt_range_uuid( ).
    LOOP AT it_pedidos INTO DATA(lv_pedido).
      IF line_exists( gt_reserva_ped[ table_line = lv_pedido ] ).
        INSERT LINES OF VALUE tt_reserva_ped( FOR r IN gt_reserva WHERE ( pedido_uuid = lv_pedido ) ( r ) )
               INTO TABLE rt_reservas.
      ELSE.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_pedido ) TO lt_range.
      ENDIF.
    ENDLOOP.

    CHECK lt_range IS NOT INITIAL.

    " Itens dos pedidos ativos, como gravados (rascunhos ficam na tabela draft):
    " uma única consulta para todos os pedidos
    SELECT PedidoUUID, ItemUUID, SUM( QtdeItemPedido ) AS Qtde
      FROM zr_pc_item_pedido
      WHERE PedidoUUID IN @lt_range
      GROUP BY PedidoUUID, ItemUUID
      INTO TABLE @DATA(lt_gravado).

    rt_reservas = VALUE #( BASE rt_reservas FOR g IN lt_gravado WHERE ( Qtde > 0 )
                           ( pedido_uuid = g-PedidoUUID item_uuid = g-ItemUUID qtde = g-Qtde ) ).
  ENDMETHOD.


  METHOD reserva_do_pedido.
    rt_qtde = VALUE #( FOR r IN it_reservas WHERE ( pedido_uuid = iv_pedido_uuid )
                       ( item_uuid = r-item_uuid qtde = r-qtde ) ).
  ENDMETHOD.


  METHOD movimentos.
    rt_mov = VALUE #( FOR p IN it_pedidos WHERE ( %is_draft = if_abap_behv=>mk-off )
                      FOR i IN it_itens WHERE ( PedidoUUID = p-PedidoUUID AND %is_draft = p-%is_draft )
                      ( is_draft    = p-%is_draft
                        pedido_uuid = p-PedidoUUID
                        item_uuid   = i-ItemUUID
                        qtde        = i-QtdeItemPedido ) ).
  ENDMETHOD.


  METHOD sem_falha.
    LOOP AT it_pedidos INTO DATA(ls_pedido).
      IF NOT line_exists( is_failed-pedido[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        APPEND ls_pedido TO rt_pedidos.
      ENDIF.
    ENDLOOP.
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
                 THEN NEW zcx_pc_msg( textid = zif_pc_msg=>pedido_finalizado_imutavel )
               WHEN zif_pc_constants=>c_status_pedido-cancelado
                 THEN NEW zcx_pc_msg( textid = zif_pc_msg=>pedido_cancelado_imutavel )
               ELSE NEW zcx_pc_msg( textid = zif_pc_msg=>pedido_status_invalido
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
                        msg         = NEW zcx_pc_msg( textid = zif_pc_msg=>pedido_status_invalido
                                                      attr1  = `Reserva de estoque` ) ) TO gt_falhas_registro.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD reservar_registro.
    " Roda quando o rascunho é salvo (Save) e o pedido é registrado como
    " instância ativa ABERTO: revalida o essencial, reserva o estoque dos itens
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

    " 1) Só a instância ativa em ABERTO reserva (rascunho não reserva)
    DATA(lt_candidatos) = VALUE tt_pedidos( FOR p IN lt_pedidos
                                            WHERE ( %is_draft    = if_abap_behv=>mk-off
                                                AND StatusPedido = zif_pc_constants=>c_status_pedido-aberto )
                                            ( p ) ).
    CHECK lt_candidatos IS NOT INITIAL.

    " Dados de apoio lidos uma única vez para todos os pedidos (fora do laço):
    " reserva já aplicada, itens do rascunho (edição de pedido já reservado),
    " situação do cliente, endereço principal e estoque atual dos itens
    DATA(lt_reservas) = reservas_atuais( VALUE #( FOR c IN lt_candidatos ( c-PedidoUUID ) ) ).

    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido BY \_Itens
        ALL FIELDS
        WITH VALUE #( FOR c IN lt_candidatos ( %is_draft = if_abap_behv=>mk-on PedidoUUID = c-PedidoUUID ) )
      RESULT DATA(lt_itens_rasc).

    DATA(lt_ids_cli) = VALUE tt_uuid( FOR c IN lt_candidatos ( c-ClienteUUID ) ).
    SELECT ClienteUUID, ClienteAtivo
      FROM zr_pc_cliente
      FOR ALL ENTRIES IN @lt_ids_cli
      WHERE ClienteUUID = @lt_ids_cli-table_line
      INTO TABLE @DATA(lt_clientes).
    DATA(lt_enderecos) = enderecos_principais( lt_ids_cli ).

    DATA(lt_ids_item) = VALUE tt_uuid( FOR i IN lt_itens ( i-ItemUUID ) ).
    INSERT LINES OF VALUE tt_uuid( FOR r IN lt_itens_rasc ( r-ItemUUID ) ) INTO TABLE lt_ids_item.
    IF lt_ids_item IS NOT INITIAL.
      SELECT ItemUUID, Sku, ItemAtivo, PrecoUnitario, Currency, QtdeEstoque, QtdeReservada
        FROM zr_pc_item
        FOR ALL ENTRIES IN @lt_ids_item
        WHERE ItemUUID = @lt_ids_item-table_line
        INTO TABLE @DATA(lt_estoque).
    ENDIF.

    TYPES:
      BEGIN OF ty_registro,
        pedido   TYPE ts_pedido,
        itens    TYPE tt_itens_pedido,
        qtde     TYPE tt_qtde_item,
        velho    TYPE tt_qtde_item,
        endereco TYPE ty_endereco_cli,
      END OF ty_registro.
    DATA lt_registros    TYPE STANDARD TABLE OF ty_registro WITH EMPTY KEY.
    DATA lt_mov_reservar TYPE tt_mov_pedido.
    DATA lt_mov_liberar  TYPE tt_mov_pedido.

    LOOP AT lt_candidatos INTO DATA(ls_pedido).
      DATA(lv_erro) = abap_false.

      " 2) Itens do pedido e diferença em relação ao que já está reservado
      DATA(lt_itens_ped) = VALUE tt_itens_pedido( FOR i IN lt_itens
                                                  WHERE ( PedidoUUID = ls_pedido-PedidoUUID
                                                          AND %is_draft = ls_pedido-%is_draft )
                                                  ( i ) ).
      DATA(lt_velho) = reserva_do_pedido( it_reservas = lt_reservas iv_pedido_uuid = ls_pedido-PedidoUUID ).

      " Edição de pedido já reservado: na ativação, os itens apagados no rascunho
      " ainda não saíram da instância ativa; a quantidade nova vem do rascunho.
      IF lt_velho IS NOT INITIAL.
        DATA(lt_rasc_ped) = VALUE tt_itens_pedido( FOR r IN lt_itens_rasc
                                                   WHERE ( PedidoUUID = ls_pedido-PedidoUUID )
                                                   ( r ) ).
        IF lt_rasc_ped IS NOT INITIAL.
          lt_itens_ped = lt_rasc_ped.
        ENDIF.
      ENDIF.

      IF lt_itens_ped IS INITIAL.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zif_pc_msg=>pedido_sem_itens )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(lt_qtde) = somar_quantidades( lt_itens_ped ).

      DATA lt_reservar TYPE tt_qtde_item.
      DATA lt_liberar  TYPE tt_qtde_item.
      DATA lv_antes    TYPE i.
      CLEAR: lt_reservar, lt_liberar.
      LOOP AT lt_qtde INTO DATA(ls_novo).
        CLEAR lv_antes.
        READ TABLE lt_velho INTO DATA(ls_antes) WITH TABLE KEY item_uuid = ls_novo-item_uuid.
        IF sy-subrc = 0.
          lv_antes = ls_antes-qtde.
        ENDIF.
        IF ls_novo-qtde > lv_antes.
          INSERT VALUE #( item_uuid = ls_novo-item_uuid qtde = ls_novo-qtde - lv_antes ) INTO TABLE lt_reservar.
        ELSEIF ls_novo-qtde < lv_antes.
          INSERT VALUE #( item_uuid = ls_novo-item_uuid qtde = lv_antes - ls_novo-qtde ) INTO TABLE lt_liberar.
        ENDIF.
      ENDLOOP.
      " Itens removidos do pedido: libera tudo o que estava reservado
      LOOP AT lt_velho INTO DATA(ls_removido).
        IF NOT line_exists( lt_qtde[ item_uuid = ls_removido-item_uuid ] ).
          INSERT VALUE #( item_uuid = ls_removido-item_uuid qtde = ls_removido-qtde ) INTO TABLE lt_liberar.
        ENDIF.
      ENDLOOP.

      " Pedido já reservado e itens iguais (ex.: pagamento recusado): nada a fazer
      IF lt_reservar IS INITIAL AND lt_liberar IS INITIAL AND lt_velho IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      " 3) Cliente ativo (lido antes do laço)
      READ TABLE lt_clientes INTO DATA(ls_cliente) WITH KEY ClienteUUID = ls_pedido-ClienteUUID.
      IF sy-subrc <> 0 OR ls_cliente-ClienteAtivo = abap_false.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zif_pc_msg=>cliente_inativo )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        lv_erro = abap_true.
      ENDIF.

      " 3) Endereço pertencente ao cliente e marcado como principal
      DATA(ls_endereco) = VALUE ty_endereco_cli( lt_enderecos[ cliente_uuid = ls_pedido-ClienteUUID ] OPTIONAL ).
      IF ls_endereco-endereco_uuid IS INITIAL.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zif_pc_msg=>cliente_sem_endereco_principal )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        lv_erro = abap_true.
      ENDIF.

      " 4) Estoque atual (dados definitivos do banco, não da UI; lido antes do laço)
      LOOP AT lt_itens_ped INTO DATA(ls_item_ped).
        READ TABLE lt_estoque INTO DATA(ls_estoque) WITH KEY ItemUUID = ls_item_ped-ItemUUID.
        " Item inativo só barra itens novos ou com quantidade maior (os já reservados seguem)
        IF ( sy-subrc <> 0 OR ls_estoque-ItemAtivo = abap_false )
           AND line_exists( lt_reservar[ item_uuid = ls_item_ped-ItemUUID ] ).
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zif_pc_msg=>item_inativo
                                                       attr1  = COND string( WHEN sy-subrc = 0 THEN ls_estoque-Sku ELSE `?` ) )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ELSEIF ls_item_ped-QtdeItemPedido <= 0.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zif_pc_msg=>item_qtde_invalida )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ELSEIF ls_estoque-Currency <> zif_pc_constants=>c_moeda_padrao.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zif_pc_msg=>valor_invalido attr1 = 'Moeda do item' )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ENDIF.
        CLEAR ls_estoque.
      ENDLOOP.

      " 5) Disponibilidade do que precisa ser reservado a mais (pré-validação;
      "    a definitiva ocorre sob lock no BO Item)
      LOOP AT lt_reservar INTO DATA(ls_a_reservar).
        READ TABLE lt_estoque INTO ls_estoque WITH KEY ItemUUID = ls_a_reservar-item_uuid.
        IF sy-subrc = 0 AND ls_a_reservar-qtde > ls_estoque-QtdeEstoque - ls_estoque-QtdeReservada.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zif_pc_msg=>item_estoque_insuficiente
                                                       attr1  = ls_estoque-Sku
                                                       attr2  = |{ ls_estoque-QtdeEstoque - ls_estoque-QtdeReservada }| )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          lv_erro = abap_true.
        ENDIF.
      ENDLOOP.

      IF lv_erro = abap_true.
        CONTINUE.
      ENDIF.

      " Pedido apto: movimentos e dados guardados para o processamento em lote
      lt_mov_liberar  = VALUE #( BASE lt_mov_liberar FOR l IN lt_liberar
                                 ( is_draft = ls_pedido-%is_draft pedido_uuid = ls_pedido-PedidoUUID
                                   item_uuid = l-item_uuid qtde = l-qtde ) ).
      lt_mov_reservar = VALUE #( BASE lt_mov_reservar FOR x IN lt_reservar
                                 ( is_draft = ls_pedido-%is_draft pedido_uuid = ls_pedido-PedidoUUID
                                   item_uuid = x-item_uuid qtde = x-qtde ) ).
      APPEND VALUE #( pedido   = ls_pedido
                      itens    = lt_itens_ped
                      qtde     = lt_qtde
                      velho    = lt_velho
                      endereco = ls_endereco ) TO lt_registros.
    ENDLOOP.

    CHECK lt_registros IS NOT INITIAL.

    " 6) Libera o que sobrou (itens removidos ou com quantidade menor) e reserva
    "    o que faltou: uma chamada EML ao BO Item por tipo de movimento, para
    "    todos os pedidos (lock e releitura no BO Item). Pedido que falha na
    "    liberação não reserva.
    movimentar_estoque( EXPORTING iv_acao     = c_mov-liberar
                                  it_mov      = lt_mov_liberar
                        IMPORTING et_falhou   = DATA(lt_falhou_lib)
                        CHANGING  cs_failed   = failed
                                  cs_reported = reported ).
    LOOP AT lt_falhou_lib INTO DATA(ls_falhou).
      DELETE lt_mov_reservar WHERE pedido_uuid = ls_falhou-pedido_uuid.
    ENDLOOP.

    movimentar_estoque( EXPORTING iv_acao     = c_mov-reservar
                                  it_mov      = lt_mov_reservar
                        IMPORTING et_falhou   = DATA(lt_falhou_res)
                        CHANGING  cs_failed   = failed
                                  cs_reported = reported ).

    DATA lt_upd_itens TYPE TABLE FOR UPDATE zr_pc_pedido\\ItemPedido.
    DATA lt_upd_ped   TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.

    LOOP AT lt_registros INTO DATA(ls_reg).
      IF line_exists( lt_falhou_lib[ pedido_uuid = ls_reg-pedido-PedidoUUID ] )
         OR line_exists( lt_falhou_res[ pedido_uuid = ls_reg-pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

      " Registra o que ficou reservado ANTES de qualquer MODIFY: as alterações abaixo
      " disparam esta determination de novo (aninhada), que então só vê a diferença (zero)
      DELETE gt_reserva WHERE pedido_uuid = ls_reg-pedido-PedidoUUID.
      INSERT LINES OF VALUE tt_reserva_ped( FOR q IN ls_reg-qtde
                                            ( pedido_uuid = ls_reg-pedido-PedidoUUID
                                              item_uuid   = q-item_uuid
                                              qtde        = q-qtde ) ) INTO TABLE gt_reserva.
      INSERT ls_reg-pedido-PedidoUUID INTO TABLE gt_reserva_ped.

      " 7) Fixa o preço unitário nos itens do pedido / 8) calcula o total
      DATA(lv_total) = CONV zr_pc_pedido-ValorTotal( 0 ).

      LOOP AT ls_reg-itens INTO DATA(ls_item_preco).
        READ TABLE lt_estoque INTO DATA(ls_estoque_preco) WITH KEY ItemUUID = ls_item_preco-ItemUUID.
        IF sy-subrc <> 0.
          CLEAR ls_estoque_preco.
        ENDIF.
        " Item que já estava no pedido mantém o preço fixado; só item novo pega o preço atual
        DATA(lv_preco) = ls_estoque_preco-PrecoUnitario.
        IF ls_item_preco-PrecoUnitarioSnapshot IS NOT INITIAL
           AND line_exists( ls_reg-velho[ item_uuid = ls_item_preco-ItemUUID ] ).
          lv_preco = ls_item_preco-PrecoUnitarioSnapshot.
        ENDIF.
        DATA(lv_valor_item) = CONV zr_pc_item_pedido-ValorTotal( ls_item_preco-QtdeItemPedido * lv_preco ).
        lv_total += lv_valor_item.
        APPEND VALUE #( %tky                  = ls_item_preco-%tky
                        PrecoUnitarioSnapshot = lv_preco
                        Currency              = ls_estoque_preco-Currency
                        ValorTotal            = lv_valor_item
                        %control = VALUE #( PrecoUnitarioSnapshot = if_abap_behv=>mk-on
                                            Currency              = if_abap_behv=>mk-on
                                            ValorTotal            = if_abap_behv=>mk-on ) ) TO lt_upd_itens.
      ENDLOOP.

      APPEND VALUE #( %tky                      = ls_reg-pedido-%tky
                      ValorTotal                = lv_total
                      Currency                  = zif_pc_constants=>c_moeda_padrao
                      EnderecoUUID              = ls_reg-endereco-endereco_uuid
                      EnderecoPrincipalCompleto = ls_reg-endereco-completo
                      %control = VALUE #( ValorTotal                = if_abap_behv=>mk-on
                                          Currency                  = if_abap_behv=>mk-on
                                          EnderecoUUID              = if_abap_behv=>mk-on
                                          EnderecoPrincipalCompleto = if_abap_behv=>mk-on ) ) TO lt_upd_ped.
    ENDLOOP.

    CHECK lt_upd_ped IS NOT INITIAL.

    " 10) StatusEstoque já recalculado pelo BO Item / 11) preços e totais de
    "     todos os pedidos numa única chamada EML
    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY ItemPedido
        UPDATE FROM lt_upd_itens
      ENTITY Pedido
        UPDATE FROM lt_upd_ped
      FAILED DATA(ls_failed_conf)
      REPORTED DATA(ls_reported_conf).

    propagar( EXPORTING is_failed = ls_failed_conf is_reported = ls_reported_conf
              CHANGING  cs_failed = failed cs_reported = reported ).

    LOOP AT lt_registros INTO ls_reg.
      CHECK line_exists( lt_upd_ped[ PedidoUUID = ls_reg-pedido-PedidoUUID ] )
        AND NOT line_exists( failed-pedido[ PedidoUUID = ls_reg-pedido-PedidoUUID ] ).

      APPEND VALUE #( %tky = ls_reg-pedido-%tky
                      %msg = COND #( WHEN ls_reg-velho IS INITIAL
                                     THEN zcx_pc_msg=>sucesso( textid = zif_pc_msg=>pedido_confirmado
                                                               attr1  = ls_reg-pedido-NumeroPedido )
                                     ELSE zcx_pc_msg=>texto( iv_texto    = |Pedido { ls_reg-pedido-NumeroPedido } atualizado. Reserva de estoque ajustada.|
                                                             iv_severity = if_abap_behv_message=>severity-success ) ) )
             TO reported-pedido.
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

    " Resultado da simulação de um pedido, aplicado depois em lote
    TYPES:
      BEGIN OF ty_simulacao,
        pedido TYPE ts_pedido,
        sim    TYPE zif_pc_pagamento_sim=>ty_resultado,
      END OF ty_simulacao.

    DATA lt_simulacoes TYPE STANDARD TABLE OF ty_simulacao WITH EMPTY KEY.
    DATA lt_upd_pag    TYPE TABLE FOR UPDATE zr_pc_pedido\\Pagamento.
    DATA lt_cre_pag    TYPE TABLE FOR CREATE zr_pc_pedido\\Pedido\_Pagamento.
    DATA lt_upd_ped    TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.
    DATA lv_agora      TYPE timestampl.

    GET TIME STAMP FIELD lv_agora.

*---------------------------------------------------------------------*
    " 1) Status do pedido e simulação (somente em memória)
*---------------------------------------------------------------------*

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_pedidos INTO DATA(ls_pedido)
           WITH KEY PedidoUUID = ls_key-PedidoUUID %is_draft = ls_key-%is_draft.
      CHECK sy-subrc = 0.

      IF ls_pedido-%is_draft = if_abap_behv=>mk-on
         OR ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-aberto.
        registrar_erro( EXPORTING is_pedido = ls_pedido io_msg = erro_status( ls_pedido )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " Dados do cartão: somente em memória, nunca persistidos
      DATA(ls_sim) = zcl_pc_pagamento_sim=>simular( VALUE #( metodo   = ls_key-%param-MetodoPagamento
                                                             numero   = ls_key-%param-NumeroCartao
                                                             validade = ls_key-%param-Validade
                                                             cvv      = ls_key-%param-Cvv ) ).

      " Formato já conferido no precheck; aqui só por segurança (chamadas internas)
      IF ls_sim-dados_validos = abap_false.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zif_pc_msg=>cartao_dados_invalidos
                                                     attr1  = ls_sim-erro )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( pedido = ls_pedido sim = ls_sim ) TO lt_simulacoes.
    ENDLOOP.

    CHECK lt_simulacoes IS NOT INITIAL.

*---------------------------------------------------------------------*
    " 2) Pagamentos: apenas a última tentativa segura é mantida (atualiza a
    "    existente ou cria a primeira), numa única chamada EML
*---------------------------------------------------------------------*

    LOOP AT lt_simulacoes INTO DATA(ls_simulacao).
      DATA(lv_idx) = sy-tabix.

      READ TABLE lt_pagamentos INTO DATA(ls_pag)
           WITH KEY PedidoUUID = ls_simulacao-pedido-PedidoUUID %is_draft = ls_simulacao-pedido-%is_draft.
      IF sy-subrc = 0.
        APPEND VALUE #( %tky                  = ls_pag-%tky
                        MetodoPagamento       = ls_simulacao-sim-metodo
                        StatusPagamento       = ls_simulacao-sim-status
                        BandeiraCartao        = ls_simulacao-sim-bandeira
                        Ultimos4DigitosCartao = ls_simulacao-sim-ultimos4
                        CartaoMascarado       = ls_simulacao-sim-cartao_mascarado
                        CodigoAutorizacao     = ls_simulacao-sim-codigo_autorizacao
                        MensagemPagamento     = ls_simulacao-sim-mensagem
                        DataPagamento         = lv_agora ) TO lt_upd_pag.
      ELSE.
        APPEND VALUE #( %tky    = ls_simulacao-pedido-%tky
                        %target = VALUE #( ( %cid                  = |PAGAMENTO{ lv_idx }|
                                             %is_draft             = ls_simulacao-pedido-%is_draft
                                             MetodoPagamento       = ls_simulacao-sim-metodo
                                             StatusPagamento       = ls_simulacao-sim-status
                                             BandeiraCartao        = ls_simulacao-sim-bandeira
                                             Ultimos4DigitosCartao = ls_simulacao-sim-ultimos4
                                             CartaoMascarado       = ls_simulacao-sim-cartao_mascarado
                                             CodigoAutorizacao     = ls_simulacao-sim-codigo_autorizacao
                                             MensagemPagamento     = ls_simulacao-sim-mensagem
                                             DataPagamento         = lv_agora ) ) ) TO lt_cre_pag.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pagamento
        UPDATE FIELDS ( MetodoPagamento StatusPagamento BandeiraCartao Ultimos4DigitosCartao
                        CartaoMascarado CodigoAutorizacao MensagemPagamento DataPagamento )
        WITH lt_upd_pag
      ENTITY Pedido
        CREATE BY \_Pagamento
        FIELDS ( MetodoPagamento StatusPagamento BandeiraCartao Ultimos4DigitosCartao
                 CartaoMascarado CodigoAutorizacao MensagemPagamento DataPagamento )
        WITH lt_cre_pag
      FAILED DATA(ls_failed_pag)
      REPORTED DATA(ls_reported_pag).

    propagar( EXPORTING is_failed = ls_failed_pag is_reported = ls_reported_pag
              CHANGING  cs_failed = failed cs_reported = reported ).

    " Pedidos cujo pagamento não pôde ser gravado: atualização -> dono do
    " pagamento existente; criação -> %cid PAGAMENTO<n> = n-ésima simulação
    DATA lt_pag_falhou TYPE tt_uuid.
    LOOP AT ls_failed_pag-pagamento INTO DATA(ls_fail_pag).
      READ TABLE lt_pagamentos INTO DATA(ls_pag_falhou) WITH KEY PagamentoUUID = ls_fail_pag-PagamentoUUID.
      IF sy-subrc = 0.
        INSERT ls_pag_falhou-PedidoUUID INTO TABLE lt_pag_falhou.
      ELSEIF ls_fail_pag-%cid IS NOT INITIAL.
        READ TABLE lt_simulacoes INTO DATA(ls_sim_falhou) INDEX CONV i( match( val = ls_fail_pag-%cid pcre = `\d+` ) ).
        IF sy-subrc = 0.
          INSERT ls_sim_falhou-pedido-PedidoUUID INTO TABLE lt_pag_falhou.
        ENDIF.
      ENDIF.
    ENDLOOP.

*---------------------------------------------------------------------*
    " 3) Status do pedido conforme o resultado, numa única chamada EML
*---------------------------------------------------------------------*

    LOOP AT lt_simulacoes INTO ls_simulacao.
      " Pagamento que não pôde ser gravado: o pedido não muda de status
      IF line_exists( failed-pedido[ PedidoUUID = ls_simulacao-pedido-PedidoUUID ] )
         OR line_exists( lt_pag_falhou[ table_line = ls_simulacao-pedido-PedidoUUID ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky            = ls_simulacao-pedido-%tky
                      StatusPagamento = ls_simulacao-sim-status
                      StatusPedido    = COND #( WHEN ls_simulacao-sim-status = zif_pc_constants=>c_status_pagamento-aprovado
                                                THEN zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                                ELSE zif_pc_constants=>c_status_pedido-aberto )
                      %control = VALUE #( StatusPagamento = if_abap_behv=>mk-on
                                          StatusPedido    = if_abap_behv=>mk-on ) ) TO lt_upd_ped.
    ENDLOOP.

    CHECK lt_upd_ped IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido UPDATE FROM lt_upd_ped
      FAILED DATA(ls_failed_ped)
      REPORTED DATA(ls_reported_ped).

    propagar( EXPORTING is_failed = ls_failed_ped is_reported = ls_reported_ped
              CHANGING  cs_failed = failed cs_reported = reported ).

    " 4) Recusa não é erro técnico: o pedido segue aguardando nova tentativa.
    "    Informação (e não aviso): em ações o Fiori Elements trata aviso como
    "    HTTP 412 e pede um segundo "Continuar?", que descartaria a tentativa.
    LOOP AT lt_upd_ped INTO DATA(ls_upd).
      CHECK NOT line_exists( failed-pedido[ PedidoUUID = ls_upd-PedidoUUID ] ).
      APPEND VALUE #( %tky = ls_upd-%tky
                      %msg = COND #( WHEN ls_upd-StatusPagamento = zif_pc_constants=>c_status_pagamento-aprovado
                                     THEN zcx_pc_msg=>sucesso( zif_pc_msg=>pagamento_aprovado )
                                     ELSE NEW zcx_pc_msg( textid   = zif_pc_msg=>pagamento_recusado
                                                          severity = if_abap_behv_message=>severity-information ) ) )
             TO reported-pedido.
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


  METHOD precheck_simular_pagamento.

    LOOP AT keys INTO DATA(ls_key).

*---------------------------------------------------------------------*
      " 1) Validação de todos os campos do parâmetro (mesmas regras da
      "    simulação, ver ZCL_PC_PAGAMENTO_SIM=>validar)
*---------------------------------------------------------------------*

      DATA(lt_erros) = zcl_pc_pagamento_sim=>validar( VALUE #( metodo   = ls_key-%param-MetodoPagamento
                                                              numero   = ls_key-%param-NumeroCartao
                                                              validade = ls_key-%param-Validade
                                                              cvv      = ls_key-%param-Cvv ) ).
      CHECK lt_erros IS NOT INITIAL.

*---------------------------------------------------------------------*
      " 2) Recusa a action com uma mensagem por campo: obrigatório (023)
      "    ou formato inválido (032)
*---------------------------------------------------------------------*

      APPEND VALUE #( %tky = ls_key-%tky ) TO failed-pedido.

      reported-pedido = VALUE #( BASE reported-pedido
                                 FOR e IN lt_erros
                                 ( %tky = ls_key-%tky
                                   %msg = COND #( WHEN e-obrigatorio = abap_true
                                                  THEN NEW zcx_pc_msg( textid = zif_pc_msg=>campo_obrigatorio
                                                                       attr1  = e-campo )
                                                  ELSE NEW zcx_pc_msg( textid = zif_pc_msg=>cartao_dados_invalidos
                                                                       attr1  = e-mensagem ) ) ) ).
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

    DATA lt_aprovar TYPE tt_pedidos.

*---------------------------------------------------------------------*
    " 1) Status AGUARDANDO_APROVACAO / 2) pagamento aprovado (memória)
*---------------------------------------------------------------------*

    LOOP AT lt_pedidos INTO DATA(ls_pedido).
      IF ls_pedido-%is_draft = if_abap_behv=>mk-off
         AND ls_pedido-StatusPedido = zif_pc_constants=>c_status_pedido-aberto.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zif_pc_msg=>pedido_pagamento_pendente )
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
                                  io_msg    = NEW #( textid = zif_pc_msg=>pedido_pagamento_pendente )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.
      APPEND ls_pedido TO lt_aprovar.
    ENDLOOP.

    CHECK lt_aprovar IS NOT INITIAL.

*---------------------------------------------------------------------*
    " 3) Estoque reservado correspondente (pré-validação): estoque de todos
    "    os itens lido numa única consulta
*---------------------------------------------------------------------*

    DATA(lt_mov) = movimentos( it_pedidos = lt_aprovar it_itens = lt_itens ).
    IF lt_mov IS NOT INITIAL.
      SELECT ItemUUID, Sku, QtdeEstoque, QtdeReservada
        FROM zr_pc_item
        FOR ALL ENTRIES IN @lt_mov
        WHERE ItemUUID = @lt_mov-item_uuid
        INTO TABLE @DATA(lt_estoque).
    ENDIF.

    LOOP AT lt_aprovar INTO ls_pedido.
      DATA(lt_qtde) = somar_quantidades( VALUE tt_itens_pedido( FOR i IN lt_itens
                                                                WHERE ( PedidoUUID = ls_pedido-PedidoUUID
                                                                        AND %is_draft = ls_pedido-%is_draft )
                                                                ( i ) ) ).
      LOOP AT lt_qtde INTO DATA(ls_qtde).
        READ TABLE lt_estoque INTO DATA(ls_estoque) WITH KEY ItemUUID = ls_qtde-item_uuid.
        IF sy-subrc <> 0
           OR ls_estoque-QtdeReservada < ls_qtde-qtde
           OR ls_estoque-QtdeEstoque   < ls_qtde-qtde.
          registrar_erro( EXPORTING is_pedido = ls_pedido
                                    io_msg    = NEW #( textid = zif_pc_msg=>item_reserva_inconsistente
                                                       attr1  = ls_estoque-Sku )
                          CHANGING  cs_failed = failed cs_reported = reported ).
          " Pedido inconsistente não movimenta estoque
          DELETE lt_mov WHERE pedido_uuid = ls_pedido-PedidoUUID.
        ENDIF.
        CLEAR ls_estoque.
      ENDLOOP.
    ENDLOOP.

    " 4-6) Baixa QtdeEstoque e QtdeReservada + recálculo do StatusEstoque (BO
    "      Item), uma única chamada para todos os pedidos
    movimentar_estoque( EXPORTING iv_acao     = c_mov-baixar
                                  it_mov      = lt_mov
                        IMPORTING et_falhou   = DATA(lt_falhou)
                        CHANGING  cs_failed   = failed
                                  cs_reported = reported ).

    " 7) Snapshots de cliente, endereço e itens dos pedidos ainda válidos
    lt_aprovar = sem_falha( it_pedidos = lt_aprovar is_failed = failed ).
    criar_snapshots( EXPORTING it_pedidos  = lt_aprovar
                               it_itens    = lt_itens
                               iv_motivo   = 'FINALIZACAO'
                     CHANGING  cs_failed   = failed
                               cs_reported = reported ).

*---------------------------------------------------------------------*
    " 8) DataFinalizacao / 9) FINALIZADO, numa única chamada EML
*---------------------------------------------------------------------*

    lt_aprovar = sem_falha( it_pedidos = lt_aprovar is_failed = failed ).
    CHECK lt_aprovar IS NOT INITIAL.

    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        UPDATE FIELDS ( StatusPedido DataFinalizacao )
        WITH VALUE #( FOR a IN lt_aprovar
                      ( %tky            = a-%tky
                        StatusPedido    = zif_pc_constants=>c_status_pedido-finalizado
                        DataFinalizacao = lv_agora ) )
        FAILED DATA(ls_failed_apr)
        REPORTED DATA(ls_reported_apr).

    propagar( EXPORTING is_failed = ls_failed_apr is_reported = ls_reported_apr
              CHANGING  cs_failed = failed cs_reported = reported ).

    LOOP AT sem_falha( it_pedidos = lt_aprovar is_failed = failed ) INTO ls_pedido.
      APPEND VALUE #( %tky = ls_pedido-%tky
                      %msg = zcx_pc_msg=>sucesso( textid = zif_pc_msg=>pedido_finalizado
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

    DATA lt_reembolsos TYPE tt_solicitacao.
    DATA lt_cancelar   TYPE tt_solicitacao.

*---------------------------------------------------------------------*
    " 1) Status e motivo de cada pedido (memória); separa os pagos, que
    "    vão para reembolso, dos que são cancelados direto
*---------------------------------------------------------------------*

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_pedidos INTO DATA(ls_pedido)
           WITH KEY PedidoUUID = ls_key-PedidoUUID %is_draft = ls_key-%is_draft.
      CHECK sy-subrc = 0.

      " Status permite cancelamento?
      IF ls_pedido-%is_draft = if_abap_behv=>mk-on
         OR (     ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-aberto
              AND ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-aguardando_aprovacao ).
        registrar_erro( EXPORTING is_pedido = ls_pedido io_msg = erro_status( ls_pedido )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 2) Motivo obrigatório
      DATA(lv_motivo) = condense( ls_key-%param-MotivoCancelamento ).
      IF lv_motivo IS INITIAL.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zif_pc_msg=>pedido_motivo_cancel_obrig )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 2b) Pagamento já efetuado: inicia processo de reembolso em vez de
      "     cancelar direto. O estoque permanece reservado até a decisão.
      IF ls_pedido-StatusPagamento = zif_pc_constants=>c_status_pagamento-aprovado.
        APPEND VALUE #( pedido = ls_pedido motivo = lv_motivo ) TO lt_reembolsos.
      ELSE.
        APPEND VALUE #( pedido = ls_pedido motivo = lv_motivo ) TO lt_cancelar.
      ENDIF.
    ENDLOOP.

*---------------------------------------------------------------------*
    " 3) Solicitações de reembolso de todos os pedidos pagos de uma vez
*---------------------------------------------------------------------*

    iniciar_processo_reembolso( EXPORTING it_solicitacoes = lt_reembolsos
                                CHANGING  cs_failed       = failed
                                          cs_reported     = reported ).

*---------------------------------------------------------------------*
    " 4) Libera a reserva (feita no registro do pedido, vale para todo status
    "    cancelável) e gera os snapshots, uma chamada para todos os pedidos
*---------------------------------------------------------------------*

    " Sem pedido a cancelar direto (todos foram para reembolso ou falharam)
    " o método segue apenas para montar o resultado
    DATA(lt_ped_cancelar) = VALUE tt_pedidos( FOR c IN lt_cancelar ( c-pedido ) ).

    movimentar_estoque( EXPORTING iv_acao     = c_mov-liberar
                                  it_mov      = movimentos( it_pedidos = lt_ped_cancelar it_itens = lt_itens )
                        IMPORTING et_falhou   = DATA(lt_falhou)
                        CHANGING  cs_failed   = failed
                                  cs_reported = reported ).

    " 5) Snapshots (somente se ainda não existirem)
    criar_snapshots( EXPORTING it_pedidos  = sem_falha( it_pedidos = lt_ped_cancelar is_failed = failed )
                               it_itens    = lt_itens
                               iv_motivo   = 'CANCELAMENTO'
                     CHANGING  cs_failed   = failed
                               cs_reported = reported ).

*---------------------------------------------------------------------*
    " 6) Motivo, data e usuário / 7) CANCELADO, numa única chamada EML
*---------------------------------------------------------------------*

    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    DATA lv_usuario TYPE zr_pc_pedido-CanceladoPor.
    TRY.
        lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        CLEAR lv_usuario.
    ENDTRY.

    DATA lt_upd_can TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.
    LOOP AT lt_cancelar INTO DATA(ls_cancelar).
      CHECK NOT line_exists( failed-pedido[ PedidoUUID = ls_cancelar-pedido-PedidoUUID ] ).
      APPEND VALUE #( %tky               = ls_cancelar-pedido-%tky
                      StatusPedido       = zif_pc_constants=>c_status_pedido-cancelado
                      MotivoCancelamento = ls_cancelar-motivo
                      DataCancelamento   = lv_agora
                      CanceladoPor       = lv_usuario
                      %control = VALUE #( StatusPedido       = if_abap_behv=>mk-on
                                          MotivoCancelamento = if_abap_behv=>mk-on
                                          DataCancelamento   = if_abap_behv=>mk-on
                                          CanceladoPor       = if_abap_behv=>mk-on ) ) TO lt_upd_can.
    ENDLOOP.
    IF lt_upd_can IS NOT INITIAL.
      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido UPDATE FROM lt_upd_can
        FAILED DATA(ls_failed_can)
        REPORTED DATA(ls_reported_can).

      propagar( EXPORTING is_failed = ls_failed_can is_reported = ls_reported_can
                CHANGING  cs_failed = failed cs_reported = reported ).

      LOOP AT sem_falha( it_pedidos = lt_ped_cancelar is_failed = failed ) INTO ls_pedido.
        APPEND VALUE #( %tky = ls_pedido-%tky
                        %msg = zcx_pc_msg=>sucesso( textid = zif_pc_msg=>pedido_cancelado
                                                    attr1  = ls_pedido-NumeroPedido ) ) TO reported-pedido.
      ENDLOOP.
    ENDIF.

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
    CHECK it_solicitacoes IS NOT INITIAL.

    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    DATA lv_usuario TYPE zr_pc_reembolso-SolicitadoPor.
    TRY.
        lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        CLEAR lv_usuario.
    ENDTRY.

*---------------------------------------------------------------------*
    " 1) Solicitações no BO Reembolso (root próprio, app Gestão de
    "    Reembolsos), todas numa única chamada EML. O %cid REEMBOLSO<n>
    "    liga cada solicitação ao n-ésimo pedido.
*---------------------------------------------------------------------*

    MODIFY ENTITIES OF zr_pc_reembolso
      ENTITY Reembolso
        CREATE FIELDS ( PedidoUUID NumeroPedido ClienteUUID StatusReembolso StatusPedidoAnterior
                        Currency ValorReembolso MotivoSolicitacao DataSolicitacao SolicitadoPor )
        WITH VALUE #( FOR s IN it_solicitacoes INDEX INTO lv_idx
                      ( %cid                 = |REEMBOLSO{ lv_idx }|
                        PedidoUUID           = s-pedido-PedidoUUID
                        NumeroPedido         = s-pedido-NumeroPedido
                        ClienteUUID          = s-pedido-ClienteUUID
                        StatusReembolso      = zif_pc_constants=>c_status_reembolso-pendente
                        StatusPedidoAnterior = s-pedido-StatusPedido
                        Currency             = s-pedido-Currency
                        ValorReembolso       = s-pedido-ValorTotal
                        MotivoSolicitacao    = s-motivo
                        DataSolicitacao      = lv_agora
                        SolicitadoPor        = lv_usuario ) )
      FAILED   DATA(ls_failed_reemb)
      REPORTED DATA(ls_reported_reemb).

    " Mensagens e falhas do BO Reembolso voltam para o pedido de origem
    LOOP AT ls_reported_reemb-reembolso INTO DATA(ls_rep_reemb) WHERE %msg IS BOUND.
      READ TABLE it_solicitacoes INTO DATA(ls_sol_rep)
           INDEX CONV i( match( val = ls_rep_reemb-%cid pcre = `\d+` ) ).
      IF sy-subrc = 0.
        APPEND VALUE #( %tky = ls_sol_rep-pedido-%tky %msg = ls_rep_reemb-%msg ) TO cs_reported-pedido.
      ENDIF.
    ENDLOOP.

    LOOP AT ls_failed_reemb-reembolso INTO DATA(ls_fail_reemb).
      READ TABLE it_solicitacoes INTO DATA(ls_sol_fail)
           INDEX CONV i( match( val = ls_fail_reemb-%cid pcre = `\d+` ) ).
      IF sy-subrc = 0 AND NOT line_exists( cs_failed-pedido[ PedidoUUID = ls_sol_fail-pedido-PedidoUUID ] ).
        APPEND VALUE #( %tky = ls_sol_fail-pedido-%tky ) TO cs_failed-pedido.
      ENDIF.
    ENDLOOP.

*---------------------------------------------------------------------*
    " 2) Pedidos com solicitação criada vão para PROCESSANDO_REEMBOLSO
*---------------------------------------------------------------------*

    DATA lt_upd TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.
    LOOP AT it_solicitacoes INTO DATA(ls_sol).
      CHECK NOT line_exists( cs_failed-pedido[ PedidoUUID = ls_sol-pedido-PedidoUUID ] ).
      APPEND VALUE #( %tky               = ls_sol-pedido-%tky
                      StatusPedido       = zif_pc_constants=>c_status_pedido-processando_reembolso
                      MotivoCancelamento = ls_sol-motivo
                      %control = VALUE #( StatusPedido       = if_abap_behv=>mk-on
                                          MotivoCancelamento = if_abap_behv=>mk-on ) ) TO lt_upd.
    ENDLOOP.
    CHECK lt_upd IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido UPDATE FROM lt_upd
      FAILED   DATA(ls_failed_upd)
      REPORTED DATA(ls_reported_upd).

    propagar( EXPORTING is_failed = ls_failed_upd is_reported = ls_reported_upd
              CHANGING  cs_failed = cs_failed cs_reported = cs_reported ).

    " 3) Confirmação para cada pedido enviado ao reembolso
    LOOP AT it_solicitacoes INTO ls_sol.
      CHECK NOT line_exists( cs_failed-pedido[ PedidoUUID = ls_sol-pedido-PedidoUUID ] ).
      APPEND VALUE #( %tky = ls_sol-pedido-%tky
                      %msg = zcx_pc_msg=>sucesso( textid = zif_pc_msg=>pedido_reembolso_solicitado
                                                  attr1  = ls_sol-pedido-NumeroPedido ) ) TO cs_reported-pedido.
    ENDLOOP.
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

    DATA lt_cancelar TYPE tt_pedidos.

*---------------------------------------------------------------------*
    " 1) Status permite decisão de reembolso? (memória)
*---------------------------------------------------------------------*

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_pedidos INTO DATA(ls_pedido)
           WITH KEY PedidoUUID = ls_key-PedidoUUID %is_draft = ls_key-%is_draft.
      CHECK sy-subrc = 0.

      IF ls_pedido-%is_draft = if_abap_behv=>mk-on
         OR ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-processando_reembolso.
        registrar_erro( EXPORTING is_pedido = ls_pedido io_msg = erro_status( ls_pedido )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.
      APPEND ls_pedido TO lt_cancelar.
    ENDLOOP.

    IF lt_cancelar IS NOT INITIAL.

*---------------------------------------------------------------------*
      " 2) Libera a reserva de estoque (o pedido não avança mais) e gera os
      "    snapshots, uma chamada para todos os pedidos
*---------------------------------------------------------------------*

      movimentar_estoque( EXPORTING iv_acao     = c_mov-liberar
                                    it_mov      = movimentos( it_pedidos = lt_cancelar it_itens = lt_itens )
                          IMPORTING et_falhou   = DATA(lt_falhou)
                          CHANGING  cs_failed   = failed
                                    cs_reported = reported ).

      " Snapshots somente se ainda não existirem
      criar_snapshots( EXPORTING it_pedidos  = sem_falha( it_pedidos = lt_cancelar is_failed = failed )
                                 it_itens    = lt_itens
                                 iv_motivo   = 'CANCELAMENTO'
                       CHANGING  cs_failed   = failed
                                 cs_reported = reported ).

      lt_cancelar = sem_falha( it_pedidos = lt_cancelar is_failed = failed ).
    ENDIF.

    IF lt_cancelar IS NOT INITIAL.

*---------------------------------------------------------------------*
      " 3) Pedido efetivamente cancelado e pagamento devolvido: pagamentos
      "    lidos e todos os pedidos atualizados numa única chamada EML
*---------------------------------------------------------------------*

      DATA lv_agora TYPE timestampl.
      GET TIME STAMP FIELD lv_agora.

      DATA lv_usuario TYPE zr_pc_pedido-CanceladoPor.
      TRY.
          lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
        CATCH cx_abap_context_info_error.
          CLEAR lv_usuario.
      ENDTRY.

      READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido BY \_Pagamento
          FIELDS ( StatusPagamento )
          WITH VALUE #( FOR c IN lt_cancelar ( %tky = c-%tky ) )
        RESULT DATA(lt_pag_dev).

      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido
          UPDATE FIELDS ( StatusPedido StatusPagamento DataCancelamento CanceladoPor )
          WITH VALUE #( FOR c IN lt_cancelar
                        ( %tky             = c-%tky
                          StatusPedido     = zif_pc_constants=>c_status_pedido-cancelado
                          StatusPagamento  = zif_pc_constants=>c_status_pagamento-devolvido
                          DataCancelamento = lv_agora
                          CanceladoPor     = lv_usuario ) )
        ENTITY Pagamento
          UPDATE FIELDS ( StatusPagamento )
          WITH VALUE #( FOR p IN lt_pag_dev
                        ( %tky            = p-%tky
                          StatusPagamento = zif_pc_constants=>c_status_pagamento-devolvido ) )
        FAILED   DATA(ls_failed_apr)
        REPORTED DATA(ls_reported_apr).

      propagar( EXPORTING is_failed = ls_failed_apr is_reported = ls_reported_apr
                CHANGING  cs_failed = failed cs_reported = reported ).
    ENDIF.

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
    DATA lt_upd_ret TYPE TABLE FOR UPDATE zr_pc_pedido\\Pedido.

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
         OR ls_pedido-StatusPedido <> zif_pc_constants=>c_status_pedido-processando_reembolso.
        registrar_erro( EXPORTING is_pedido = ls_pedido io_msg = erro_status( ls_pedido )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 2) Status anterior à solicitação, informado pelo BO Reembolso
      DATA(lv_status_anterior) = CONV zr_pc_pedido-StatusPedido( condense( ls_key-%param-StatusAnterior ) ).
      IF lv_status_anterior IS INITIAL.
        registrar_erro( EXPORTING is_pedido = ls_pedido
                                  io_msg    = NEW #( textid = zif_pc_msg=>campo_obrigatorio
                                                     attr1  = 'Status anterior' )
                        CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 3) Pedido volta ao status anterior e o motivo do cancelamento é limpo
      "    (acumulado para uma única chamada EML)
      APPEND VALUE #( %tky               = ls_pedido-%tky
                      StatusPedido       = lv_status_anterior
                      MotivoCancelamento = ''
                      %control = VALUE #( StatusPedido       = if_abap_behv=>mk-on
                                          MotivoCancelamento = if_abap_behv=>mk-on ) ) TO lt_upd_ret.
    ENDLOOP.

    IF lt_upd_ret IS NOT INITIAL.
      MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
        ENTITY Pedido UPDATE FROM lt_upd_ret
        FAILED   DATA(ls_failed_rej)
        REPORTED DATA(ls_reported_rej).

      propagar( EXPORTING is_failed = ls_failed_rej is_reported = ls_reported_rej
                CHANGING  cs_failed = failed cs_reported = reported ).
    ENDIF.

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

    CLEAR et_falhou.
    CHECK it_mov IS NOT INITIAL.

*---------------------------------------------------------------------*
    " 1) Uma linha por item com a quantidade somada de todos os pedidos
*---------------------------------------------------------------------*

    DATA(lt_total) = VALUE tt_qtde_item( FOR GROUPS g OF m IN it_mov GROUP BY m-item_uuid
                                         ( item_uuid = g
                                           qtde      = REDUCE i( INIT s = 0 FOR r IN GROUP g NEXT s = s + r-qtde ) ) ).

    SELECT ItemUUID, Sku
      FROM zr_pc_item
      FOR ALL ENTRIES IN @lt_total
      WHERE ItemUUID = @lt_total-item_uuid
      INTO TABLE @DATA(lt_sku).

*---------------------------------------------------------------------*
    " 2) Movimento no BO Item, uma única chamada EML. O framework bloqueia
    "    cada item (lock master) antes da action; se outro usuário/transação
    "    estiver com o item bloqueado, a operação falha e os pedidos que usam
    "    o item recebem ITEM_ESTOQUE_CONCORRENTE.
*---------------------------------------------------------------------*

    CASE iv_acao.
      WHEN c_mov-reservar.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE ReservarEstoque
            FROM VALUE #( FOR q IN lt_total ( ItemUUID = q-item_uuid %param-Quantidade = q-qtde ) )
          FAILED ls_failed_item
          REPORTED ls_reported_item.

      WHEN c_mov-liberar.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE LiberarReserva
            FROM VALUE #( FOR q IN lt_total ( ItemUUID = q-item_uuid %param-Quantidade = q-qtde ) )
          FAILED ls_failed_item
          REPORTED ls_reported_item.

      WHEN c_mov-baixar.
        MODIFY ENTITIES OF zr_pc_item
          ENTITY Item
            EXECUTE BaixarEstoque
            FROM VALUE #( FOR q IN lt_total ( ItemUUID = q-item_uuid %param-Quantidade = q-qtde ) )
          FAILED ls_failed_item
          REPORTED ls_reported_item.
    ENDCASE.

    " 3) Mensagens do BO Item repassadas a cada pedido que usa o item
    LOOP AT ls_reported_item-item INTO DATA(ls_rep_item) WHERE %msg IS BOUND.
      LOOP AT it_mov INTO DATA(ls_mov) WHERE item_uuid = ls_rep_item-ItemUUID.
        APPEND VALUE #( %tky-%is_draft  = ls_mov-is_draft
                        %tky-PedidoUUID = ls_mov-pedido_uuid
                        %msg            = ls_rep_item-%msg ) TO cs_reported-pedido.
      ENDLOOP.
    ENDLOOP.

    CHECK ls_failed_item-item IS NOT INITIAL.

*---------------------------------------------------------------------*
    " 4) Item recusado faz falhar todos os pedidos que o usam. Falha sem
    "    mensagem própria (ex.: lock) => concorrência
*---------------------------------------------------------------------*

    LOOP AT ls_failed_item-item INTO DATA(ls_fail_item).
      DATA(lv_sem_msg) = xsdbool( NOT line_exists( ls_reported_item-item[ ItemUUID = ls_fail_item-ItemUUID ] ) ).
      READ TABLE lt_sku INTO DATA(ls_sku) WITH KEY ItemUUID = ls_fail_item-ItemUUID.
      DATA(lv_sku) = COND string( WHEN sy-subrc = 0 THEN ls_sku-Sku ELSE `?` ).

      LOOP AT it_mov INTO ls_mov WHERE item_uuid = ls_fail_item-ItemUUID.
        IF NOT line_exists( et_falhou[ is_draft = ls_mov-is_draft pedido_uuid = ls_mov-pedido_uuid ] ).
          APPEND VALUE #( is_draft = ls_mov-is_draft pedido_uuid = ls_mov-pedido_uuid ) TO et_falhou.
        ENDIF.
        IF lv_sem_msg = abap_true.
          APPEND VALUE #( %tky-%is_draft  = ls_mov-is_draft
                          %tky-PedidoUUID = ls_mov-pedido_uuid
                          %msg            = NEW zcx_pc_msg( textid = zif_pc_msg=>item_estoque_concorrente
                                                            attr1  = lv_sku ) ) TO cs_reported-pedido.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    LOOP AT et_falhou INTO DATA(ls_falhou).
      IF NOT line_exists( cs_failed-pedido[ PedidoUUID = ls_falhou-pedido_uuid ] ).
        APPEND VALUE #( %tky-%is_draft  = ls_falhou-is_draft
                        %tky-PedidoUUID = ls_falhou-pedido_uuid ) TO cs_failed-pedido.
      ENDIF.
    ENDLOOP.

    CHECK iv_acao = c_mov-reservar.

*---------------------------------------------------------------------*
    " 5) Compensação: evita reserva parcial. Os itens aceitos dos pedidos que
    "    falharam foram reservados na chamada acima; a parte desses pedidos é
    "    liberada numa única chamada EML.
*---------------------------------------------------------------------*

    DATA lt_comp TYPE tt_mov_pedido.
    LOOP AT it_mov INTO ls_mov.
      IF line_exists( et_falhou[ is_draft = ls_mov-is_draft pedido_uuid = ls_mov-pedido_uuid ] )
         AND NOT line_exists( ls_failed_item-item[ ItemUUID = ls_mov-item_uuid ] ).
        APPEND ls_mov TO lt_comp.
      ENDIF.
    ENDLOOP.

    CHECK lt_comp IS NOT INITIAL.

    DATA(lt_total_comp) = VALUE tt_qtde_item( FOR GROUPS c OF m IN lt_comp GROUP BY m-item_uuid
                                              ( item_uuid = c
                                                qtde      = REDUCE i( INIT s = 0 FOR r IN GROUP c NEXT s = s + r-qtde ) ) ).

    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        EXECUTE LiberarReserva
        FROM VALUE #( FOR t IN lt_total_comp ( ItemUUID = t-item_uuid %param-Quantidade = t-qtde ) )
      FAILED DATA(ls_failed_comp)
      REPORTED DATA(ls_reported_comp).

    " A compensação não pode falhar em silêncio: reserva presa é inconsistência
    LOOP AT ls_reported_comp-item INTO DATA(ls_rep_comp) WHERE %msg IS BOUND.
      LOOP AT lt_comp INTO ls_mov WHERE item_uuid = ls_rep_comp-ItemUUID.
        APPEND VALUE #( %tky-%is_draft  = ls_mov-is_draft
                        %tky-PedidoUUID = ls_mov-pedido_uuid
                        %msg            = ls_rep_comp-%msg ) TO cs_reported-pedido.
      ENDLOOP.
    ENDLOOP.

    LOOP AT ls_failed_comp-item INTO DATA(ls_fail_comp).
      READ TABLE lt_sku INTO DATA(ls_sku_comp) WITH KEY ItemUUID = ls_fail_comp-ItemUUID.
      DATA(lv_sku_comp) = COND string( WHEN sy-subrc = 0 THEN ls_sku_comp-Sku ELSE `?` ).
      LOOP AT lt_comp INTO ls_mov WHERE item_uuid = ls_fail_comp-ItemUUID.
        APPEND VALUE #( %tky-%is_draft  = ls_mov-is_draft
                        %tky-PedidoUUID = ls_mov-pedido_uuid
                        %msg            = NEW zcx_pc_msg( textid = zif_pc_msg=>item_reserva_inconsistente
                                                          attr1  = lv_sku_comp ) ) TO cs_reported-pedido.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD criar_snapshots.
    " Liga o %cid de cada snapshot criado ao pedido de origem
    TYPES:
      BEGIN OF ty_cid_pedido,
        cid    TYPE abp_behv_cid,
        pedido TYPE ty_pedido_key,
      END OF ty_cid_pedido.

    DATA lt_create_cli   TYPE TABLE FOR CREATE zr_pc_pedido\\Pedido\_ClienteSnapshot.
    DATA lt_create_itens TYPE TABLE FOR CREATE zr_pc_pedido\\Pedido\_ItensSnapshot.
    DATA lt_cid_pedido   TYPE SORTED TABLE OF ty_cid_pedido WITH UNIQUE KEY cid.
    DATA lt_novos        TYPE tt_pedidos.

    CHECK it_pedidos IS NOT INITIAL.

*---------------------------------------------------------------------*
    " 1) Snapshots são imutáveis e gerados uma única vez: pedidos que já
    "    têm snapshot ficam de fora (uma leitura para todos)
*---------------------------------------------------------------------*

    READ ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido BY \_ClienteSnapshot
        FIELDS ( PedidoUUID ) WITH VALUE #( FOR p IN it_pedidos ( %tky = p-%tky ) )
      RESULT DATA(lt_snap_cli)
      ENTITY Pedido BY \_ItensSnapshot
        FIELDS ( PedidoUUID ) WITH VALUE #( FOR p IN it_pedidos ( %tky = p-%tky ) )
      RESULT DATA(lt_snap_itm).

    LOOP AT it_pedidos INTO DATA(ls_pedido).
      IF line_exists( lt_snap_cli[ PedidoUUID = ls_pedido-PedidoUUID ] )
         OR line_exists( lt_snap_itm[ PedidoUUID = ls_pedido-PedidoUUID ] ).
        APPEND VALUE #( %tky = ls_pedido-%tky
                        %msg = NEW zcx_pc_msg( textid   = zif_pc_msg=>snapshot_existente
                                               severity = if_abap_behv_message=>severity-information ) )
               TO cs_reported-pedido.
      ELSE.
        APPEND ls_pedido TO lt_novos.
      ENDIF.
    ENDLOOP.

    CHECK lt_novos IS NOT INITIAL.

*---------------------------------------------------------------------*
    " 2) Dados atuais de clientes, endereços usados nos pedidos e itens:
    "    uma consulta por tabela
*---------------------------------------------------------------------*

    SELECT ClienteUUID, Cpf, Nome, Email, Telefone, Genero, DataNascimento, ClienteAtivo, ScoreCliente
      FROM zr_pc_cliente
      FOR ALL ENTRIES IN @lt_novos
      WHERE ClienteUUID = @lt_novos-ClienteUUID
      INTO TABLE @DATA(lt_clientes).

    SELECT EnderecoUUID, Cep, Logradouro, Numero, Complemento, Bairro, Cidade, Uf, Estado
      FROM zr_pc_endereco
      FOR ALL ENTRIES IN @lt_novos
      WHERE EnderecoUUID = @lt_novos-EnderecoUUID
      INTO TABLE @DATA(lt_enderecos).

    IF it_itens IS NOT INITIAL.
      SELECT ItemUUID, Sku, Nome, Descricao, Categoria
        FROM zr_pc_item
        FOR ALL ENTRIES IN @it_itens
        WHERE ItemUUID = @it_itens-ItemUUID
        INTO TABLE @DATA(lt_itens_mestre).
    ENDIF.

*---------------------------------------------------------------------*
    " 3) Monta os snapshots de todos os pedidos (memória)
*---------------------------------------------------------------------*

    DATA(lv_seq) = 0.
    LOOP AT lt_novos INTO ls_pedido.
      DATA(lv_idx) = sy-tabix.

      READ TABLE lt_clientes INTO DATA(ls_cliente) WITH KEY ClienteUUID = ls_pedido-ClienteUUID.
      IF sy-subrc <> 0.
        CLEAR ls_cliente.
      ENDIF.
      READ TABLE lt_enderecos INTO DATA(ls_endereco) WITH KEY EnderecoUUID = ls_pedido-EnderecoUUID.
      IF sy-subrc <> 0.
        CLEAR ls_endereco.
      ENDIF.

      DATA(lv_cid_cli) = CONV abp_behv_cid( |SNAP_CLIENTE_{ lv_idx }| ).
      INSERT VALUE #( cid    = lv_cid_cli
                      pedido = VALUE #( is_draft = ls_pedido-%is_draft pedido_uuid = ls_pedido-PedidoUUID ) )
             INTO TABLE lt_cid_pedido.

      APPEND VALUE #( %tky    = ls_pedido-%tky
                      %target = VALUE #( ( %cid             = lv_cid_cli
                                           %is_draft        = ls_pedido-%is_draft
                                           ClienteUUID      = ls_pedido-ClienteUUID
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
                                           EnderecoCompleto = ls_pedido-EnderecoPrincipalCompleto
                                           MotivoSnapshot   = iv_motivo ) ) ) TO lt_create_cli.

      APPEND VALUE #( %tky = ls_pedido-%tky ) TO lt_create_itens ASSIGNING FIELD-SYMBOL(<ls_create>).
      LOOP AT it_itens INTO DATA(ls_item) WHERE PedidoUUID = ls_pedido-PedidoUUID AND %is_draft = ls_pedido-%is_draft.
        lv_seq += 1.
        READ TABLE lt_itens_mestre INTO DATA(ls_mestre) WITH KEY ItemUUID = ls_item-ItemUUID.
        IF sy-subrc <> 0.
          CLEAR ls_mestre.
        ENDIF.

        DATA(lv_cid_item) = CONV abp_behv_cid( |SNAP_ITEM_{ lv_seq }| ).
        INSERT VALUE #( cid    = lv_cid_item
                        pedido = VALUE #( is_draft = ls_pedido-%is_draft pedido_uuid = ls_pedido-PedidoUUID ) )
               INTO TABLE lt_cid_pedido.

        APPEND VALUE #( %cid           = lv_cid_item
                        %is_draft      = ls_pedido-%is_draft
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
    ENDLOOP.

*---------------------------------------------------------------------*
    " 4) Criação de todos os snapshots numa única chamada EML
*---------------------------------------------------------------------*

    MODIFY ENTITIES OF zr_pc_pedido IN LOCAL MODE
      ENTITY Pedido
        CREATE BY \_ClienteSnapshot
          FIELDS ( ClienteUUID Cpf Nome Email Telefone Genero DataNascimento ClienteAtivo ScoreCliente
                   EnderecoUUID Cep Logradouro Numero Complemento Bairro Cidade Uf Estado
                   EnderecoCompleto MotivoSnapshot )
          WITH lt_create_cli
        CREATE BY \_ItensSnapshot
          FIELDS ( ItemPedidoUUID ItemUUID Sku Nome Descricao Categoria Quantidade Currency
                   PrecoUnitario ValorTotal )
          WITH lt_create_itens
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    propagar( EXPORTING is_failed = ls_failed is_reported = ls_reported
              CHANGING  cs_failed = cs_failed cs_reported = cs_reported ).

    " 5) Snapshot que falhou reprova o pedido de origem (via %cid)
    DATA(lt_cids_falha) = VALUE string_table( FOR c IN ls_failed-clientesnapshot ( CONV string( c-%cid ) ) ).
    INSERT LINES OF VALUE string_table( FOR i IN ls_failed-itemsnapshot ( CONV string( i-%cid ) ) ) INTO TABLE lt_cids_falha.

    LOOP AT lt_cids_falha INTO DATA(lv_cid_falha).
      READ TABLE lt_cid_pedido INTO DATA(ls_cid_pedido) WITH TABLE KEY cid = CONV abp_behv_cid( lv_cid_falha ).
      IF sy-subrc = 0 AND NOT line_exists( cs_failed-pedido[ PedidoUUID = ls_cid_pedido-pedido-pedido_uuid ] ).
        APPEND VALUE #( %tky-%is_draft  = ls_cid_pedido-pedido-is_draft
                        %tky-PedidoUUID = ls_cid_pedido-pedido-pedido_uuid ) TO cs_failed-pedido.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


"! <h1>Handler da entidade ItemPedido (filha do BO {@link ZR_PC_PEDIDO})</h1>
"! Valor de cada linha e validação do item escolhido.
CLASS lhc_itempedido DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      "! State areas das validations (mensagens de estado no rascunho)
      BEGIN OF c_area,
        "! {@link .METH:ValidarItemPedido}
        item TYPE string VALUE `VALIDAR_ITEM_PEDIDO`,
      END OF c_area.

    "! Preço unitário atual do item, moeda e valor da linha (quantidade x preço).
    METHODS CalcularValorItem FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ItemPedido~CalcularValorItem.

    "! Item obrigatório, ativo e quantidade maior que zero.
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
        lo_msg = NEW #( textid = zif_pc_msg=>campo_obrigatorio attr1 = 'Item' ).
      ELSEIF sy-subrc <> 0 OR ls_mestre-ItemAtivo = abap_false.
        lo_msg = NEW #( textid = zif_pc_msg=>item_inativo attr1 = ls_mestre-Sku ).
      ELSEIF ls_item-QtdeItemPedido <= 0.
        lo_msg = NEW #( textid = zif_pc_msg=>item_qtde_invalida ).
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
