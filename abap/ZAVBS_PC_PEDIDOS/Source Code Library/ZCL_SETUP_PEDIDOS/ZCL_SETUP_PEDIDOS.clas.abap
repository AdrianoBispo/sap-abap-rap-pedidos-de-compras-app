"! <p class="shorttext synchronized">Pedidos de Compras - Carga de pedidos de demonstração</p>
"! Insere 100 pedidos sobre os clientes e itens já carregados (executar depois de
"! ZCL_SETUP_CLIENTE e ZCL_SETUP_ESTOQUE). Os registros seguem o fluxo real:
"!  - status distribuídos entre CRIADO, AGUARDANDO_PAGAMENTO, AGUARDANDO_APROVACAO,
"!    FINALIZADO e CANCELADO;
"!  - 10 pedidos em PROCESSAR_REEMBOLSO, cada um com uma solicitação de reembolso
"!    PENDENTE (exibida no app de Gestão de Reembolsos);
"!  - pagamento, snapshots (finalizados/cancelados) e estoque (reserva/baixa)
"!    coerentes com o status.
"! Não roda de novo se já houver pedidos de demonstração.
CLASS zcl_setup_pedidos DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_quantidade TYPE i VALUE 100.
    CONSTANTS c_marcador TYPE string VALUE `Pedido de demonstração`.

    METHODS carregar_dados
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out
      RAISING   cx_uuid_error cx_number_ranges.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_item,
        item_uuid      TYPE zta_pc_item-item_uuid,
        sku            TYPE zta_pc_item-sku,
        nome           TYPE zta_pc_item-nome,
        descricao      TYPE zta_pc_item-descricao,
        categoria      TYPE zta_pc_item-categoria,
        qtde_estoque   TYPE i,
        qtde_reservada TYPE i,
        preco_unitario TYPE zta_pc_item-preco_unitario,
        currency       TYPE zta_pc_item-currency,
        alterado       TYPE abap_boolean,
      END OF ty_item.
    TYPES:
      BEGIN OF ty_linha,
        item_idx TYPE i,
        qtde     TYPE i,
      END OF ty_linha.
    TYPES tt_pedidos TYPE STANDARD TABLE OF zta_pc_pedido WITH EMPTY KEY.
    TYPES tt_status  TYPE STANDARD TABLE OF zif_pc_constants=>ty_status_pedido WITH EMPTY KEY.

    METHODS ts_passado
      IMPORTING iv_dias      TYPE i
                iv_horas     TYPE i
      RETURNING VALUE(rv_ts) TYPE timestampl.

    METHODS contar
      IMPORTING it_pedidos    TYPE tt_pedidos
                iv_status     TYPE zif_pc_constants=>ty_status_pedido
      RETURNING VALUE(rv_qtd) TYPE i.
ENDCLASS.



CLASS zcl_setup_pedidos IMPLEMENTATION.

  METHOD carregar_dados.
    FIELD-SYMBOLS <ls_item> TYPE ty_item.

    DATA lt_pedidos    TYPE tt_pedidos.
    DATA lt_itens_ped  TYPE STANDARD TABLE OF zta_pc_item_ped WITH EMPTY KEY.
    DATA lt_pagamentos TYPE STANDARD TABLE OF zta_pc_pagamento WITH EMPTY KEY.
    DATA lt_reembolsos TYPE STANDARD TABLE OF zta_pc_reembolso WITH EMPTY KEY.
    DATA lt_snap_cli   TYPE STANDARD TABLE OF zta_pc_snap_cli WITH EMPTY KEY.
    DATA lt_snap_itm   TYPE STANDARD TABLE OF zta_pc_snap_itm WITH EMPTY KEY.
    DATA lt_itens      TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.
    DATA lt_linhas     TYPE STANDARD TABLE OF ty_linha WITH EMPTY KEY.
    DATA lt_padrao     TYPE tt_status.
    DATA lv_reembolsos TYPE i.
    DATA lv_total      TYPE zta_pc_pedido-valor_total.

    DATA(lv_padrao_obs) = c_marcador && `%`.
    SELECT COUNT( * ) FROM zta_pc_pedido
      WHERE observacao LIKE @lv_padrao_obs
      INTO @DATA(lv_qtd_demo).
    IF lv_qtd_demo > 0.
      io_out->write( |Pedidos de demonstração já carregados ({ lv_qtd_demo }): nada a inserir.| ).
      RETURN.
    ENDIF.

    " Clientes ativos com endereço principal / itens ativos (carregados antes)
    SELECT c~cliente_uuid, c~cpf, c~nome, c~email, c~telefone, c~genero,
           c~data_nascimento, c~cliente_ativo, c~score_cliente,
           e~endereco_uuid, e~cep, e~logradouro, e~numero, e~complemento,
           e~bairro, e~cidade, e~uf, e~estado
      FROM zta_pc_cliente AS c
      INNER JOIN zta_pc_endereco AS e ON e~cliente_uuid = c~cliente_uuid
      WHERE c~cliente_ativo = @abap_true
        AND e~endereco_principal = @abap_true
      ORDER BY c~cpf
      INTO TABLE @DATA(lt_clientes).

    SELECT item_uuid, sku, nome, descricao, categoria, qtde_estoque,
           qtde_reservada, preco_unitario, currency
      FROM zta_pc_item
      WHERE item_ativo = @abap_true
      ORDER BY sku
      INTO CORRESPONDING FIELDS OF TABLE @lt_itens.

    IF lt_clientes IS INITIAL OR lt_itens IS INITIAL.
      io_out->write( `Pedidos de demonstração: carregue antes clientes e itens (ZCL_SETUP_CLIENTE / ZCL_SETUP_ESTOQUE).` ).
      RETURN.
    ENDIF.

    DATA(lv_usuario) = CONV abp_creation_user( 'SETUP' ).
    TRY.
        lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        " mantém 'SETUP'
    ENDTRY.
    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    " Padrão de 20 pedidos (repetido 5x): 6 FIN, 4 AG_APR, 3 CRIADO, 3 AG_PAG, 2 REEMB, 2 CANC
    DATA(lc_ped) = zif_pc_constants=>c_status_pedido.
    lt_padrao = VALUE #(
      ( lc_ped-finalizado )           ( lc_ped-aguardando_aprovacao ) ( lc_ped-criado )
      ( lc_ped-finalizado )           ( lc_ped-aguardando_pagamento ) ( lc_ped-processar_reembolso )
      ( lc_ped-finalizado )           ( lc_ped-aguardando_aprovacao ) ( lc_ped-cancelado )
      ( lc_ped-criado )               ( lc_ped-finalizado )           ( lc_ped-aguardando_pagamento )
      ( lc_ped-aguardando_aprovacao ) ( lc_ped-processar_reembolso )  ( lc_ped-finalizado )
      ( lc_ped-criado )               ( lc_ped-aguardando_pagamento ) ( lc_ped-cancelado )
      ( lc_ped-finalizado )           ( lc_ped-aguardando_aprovacao ) ).

    DATA(lt_motivos_cancel) = VALUE string_table(
      ( `Desistência da compra` )
      ( `Compra realizada em duplicidade` )
      ( `Endereço de entrega incorreto` )
      ( `Prazo de entrega muito longo` ) ).

    DATA(lt_motivos_reembolso) = VALUE string_table(
      ( `Produto chegou com defeito` )
      ( `Produto diferente do anunciado` )
      ( `Desistência da compra após o pagamento` )
      ( `Cobrança em duplicidade no cartão` )
      ( `Atraso na entrega` )
      ( `Pedido realizado por engano` )
      ( `Produto danificado no transporte` )
      ( `Item faltando no pedido` )
      ( `Encontrei preço menor em outra loja` )
      ( `Cobrança não reconhecida` ) ).

    DO c_quantidade TIMES.
      DATA(lv_i)      = sy-index.
      DATA(lv_status) = lt_padrao[ ( lv_i - 1 ) MOD lines( lt_padrao ) + 1 ].
      DATA(ls_cli)    = lt_clientes[ ( lv_i - 1 ) MOD lines( lt_clientes ) + 1 ].

      DATA(lv_fin)   = xsdbool( lv_status = lc_ped-finalizado ).
      DATA(lv_canc)  = xsdbool( lv_status = lc_ped-cancelado ).
      DATA(lv_reemb) = xsdbool( lv_status = lc_ped-processar_reembolso ).

      " ---- Escolha dos itens (1 a 3 linhas) com saldo disponível
      CLEAR lt_linhas.
      DATA(lv_nlinhas) = 1 + lv_i MOD 3.
      DO lv_nlinhas TIMES.
        DATA(lv_k)     = sy-index.
        DATA(lv_qtde)  = 1 + ( lv_i + lv_k ) MOD 3.
        DO lines( lt_itens ) TIMES.
          DATA(lv_idx) = ( lv_i * 7 + lv_k * 13 + sy-index ) MOD lines( lt_itens ) + 1.
          ASSIGN lt_itens[ lv_idx ] TO <ls_item>.
          IF <ls_item>-qtde_estoque - <ls_item>-qtde_reservada >= lv_qtde
             AND NOT line_exists( lt_linhas[ item_idx = lv_idx ] ).
            APPEND VALUE #( item_idx = lv_idx qtde = lv_qtde ) TO lt_linhas.
            EXIT.
          ENDIF.
        ENDDO.
      ENDDO.

      IF lt_linhas IS INITIAL.
        io_out->write( |Pedido { lv_i } ignorado: sem item com saldo disponível.| ).
        CONTINUE.
      ENDIF.

      " ---- Datas: do mais antigo (~90 dias) ao mais recente (~2 dias)
      DATA(lv_dias)   = 2 + ( c_quantidade - lv_i ) * 88 DIV c_quantidade.
      DATA(lv_criado) = ts_passado( iv_dias = lv_dias iv_horas = lv_i MOD 24 ).
      DATA(lv_evento) = ts_passado( iv_dias = lv_dias - 1 iv_horas = lv_i MOD 24 ).

      DATA(lv_pedido_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
      DATA(lv_motivo_snap) = COND string( WHEN lv_fin = abap_true THEN `FINALIZACAO` ELSE `CANCELAMENTO` ).

      " ---- Itens do pedido, snapshot dos itens e movimento de estoque
      CLEAR lv_total.
      LOOP AT lt_linhas INTO DATA(ls_linha).
        ASSIGN lt_itens[ ls_linha-item_idx ] TO <ls_item>.

        DATA(lv_valor_linha) = CONV zta_pc_item_ped-valor_total( ls_linha-qtde * <ls_item>-preco_unitario ).
        lv_total = lv_total + lv_valor_linha.

        DATA(lv_item_ped_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        APPEND VALUE #( item_pedido_uuid      = lv_item_ped_uuid
                        pedido_uuid           = lv_pedido_uuid
                        item_uuid             = <ls_item>-item_uuid
                        qtde_item_pedido      = ls_linha-qtde
                        currency              = <ls_item>-currency
                        preco_unitario_snap   = <ls_item>-preco_unitario
                        valor_total           = lv_valor_linha
                        created_by            = lv_usuario
                        created_at            = lv_criado
                        last_changed_by       = lv_usuario
                        last_changed_at       = lv_criado
                        local_last_changed_at = lv_criado ) TO lt_itens_ped.

        IF lv_fin = abap_true OR lv_canc = abap_true.
          APPEND VALUE #( snapshot_item_uuid    = cl_system_uuid=>create_uuid_x16_static( )
                          pedido_uuid           = lv_pedido_uuid
                          item_pedido_uuid      = lv_item_ped_uuid
                          item_uuid             = <ls_item>-item_uuid
                          sku                   = <ls_item>-sku
                          nome                  = <ls_item>-nome
                          descricao             = <ls_item>-descricao
                          categoria             = <ls_item>-categoria
                          quantidade            = ls_linha-qtde
                          currency              = <ls_item>-currency
                          preco_unitario        = <ls_item>-preco_unitario
                          valor_total           = lv_valor_linha
                          created_by            = lv_usuario
                          created_at            = lv_evento
                          last_changed_by       = lv_usuario
                          last_changed_at       = lv_evento
                          local_last_changed_at = lv_evento ) TO lt_snap_itm.
        ENDIF.

        " Finalizado: baixa do estoque. Cancelado: reserva já liberada (sem efeito).
        " Demais status: estoque reservado desde o registro do pedido.
        IF lv_fin = abap_true.
          <ls_item>-qtde_estoque = <ls_item>-qtde_estoque - ls_linha-qtde.
          <ls_item>-alterado     = abap_true.
        ELSEIF lv_canc = abap_false.
          <ls_item>-qtde_reservada = <ls_item>-qtde_reservada + ls_linha-qtde.
          <ls_item>-alterado       = abap_true.
        ENDIF.
      ENDLOOP.

      " ---- Pedido
      DATA(lv_status_pag) = COND zif_pc_constants=>ty_status_pagamento(
        WHEN lv_status = lc_ped-criado OR lv_status = lc_ped-cancelado
          THEN zif_pc_constants=>c_status_pagamento-pendente
        WHEN lv_status = lc_ped-aguardando_pagamento
          THEN zif_pc_constants=>c_status_pagamento-recusado
        ELSE zif_pc_constants=>c_status_pagamento-aprovado ).

      DATA(ls_pedido) = VALUE zta_pc_pedido(
        pedido_uuid           = lv_pedido_uuid
        numero_pedido         = zcl_pc_numeracao=>proximo_numero_pedido( )
        cliente_uuid          = ls_cli-cliente_uuid
        endereco_uuid         = ls_cli-endereco_uuid
        endereco_completo     = zcl_pc_util=>formatar_endereco( iv_logradouro  = ls_cli-logradouro
                                                                iv_numero      = ls_cli-numero
                                                                iv_complemento = ls_cli-complemento
                                                                iv_bairro      = ls_cli-bairro
                                                                iv_cidade      = ls_cli-cidade
                                                                iv_uf          = ls_cli-uf
                                                                iv_cep         = ls_cli-cep )
        status_pedido         = lv_status
        status_pagamento      = lv_status_pag
        observacao            = |{ c_marcador } { lv_i }|
        currency              = zif_pc_constants=>c_moeda_padrao
        valor_total           = lv_total
        pedido_encerrado      = xsdbool( lv_fin = abap_true OR lv_canc = abap_true )
        pedido_ativo_sem_hist = xsdbool( lv_status = lc_ped-criado
                                      OR lv_status = lc_ped-aguardando_pagamento
                                      OR lv_status = lc_ped-aguardando_aprovacao )
        created_by            = lv_usuario
        created_at            = lv_criado
        last_changed_by       = lv_usuario
        last_changed_at       = lv_evento
        local_last_changed_at = lv_evento ).

      IF lv_fin = abap_true.
        ls_pedido-data_finalizacao = lv_evento.
      ENDIF.
      IF lv_canc = abap_true.
        ls_pedido-motivo_cancelamento = lt_motivos_cancel[ ( lv_i - 1 ) MOD lines( lt_motivos_cancel ) + 1 ].
        ls_pedido-data_cancelamento   = lv_evento.
        ls_pedido-cancelado_por       = lv_usuario.
      ENDIF.

      " ---- Solicitação de reembolso (app Gestão de Reembolsos)
      IF lv_reemb = abap_true.
        lv_reembolsos = lv_reembolsos + 1.
        DATA(lv_motivo_reemb) = lt_motivos_reembolso[ ( lv_reembolsos - 1 ) MOD lines( lt_motivos_reembolso ) + 1 ].
        ls_pedido-motivo_cancelamento = lv_motivo_reemb.

        APPEND VALUE #( reembolso_uuid          = cl_system_uuid=>create_uuid_x16_static( )
                        pedido_uuid             = lv_pedido_uuid
                        numero_pedido           = ls_pedido-numero_pedido
                        cliente_uuid            = ls_cli-cliente_uuid
                        status_reembolso        = zif_pc_constants=>c_status_reembolso-pendente
                        status_pedido_anterior  = lc_ped-aguardando_aprovacao
                        currency                = zif_pc_constants=>c_moeda_padrao
                        valor_reembolso         = lv_total
                        motivo_solicitacao      = lv_motivo_reemb
                        data_solicitacao        = lv_evento
                        solicitado_por          = lv_usuario
                        created_by              = lv_usuario
                        created_at              = lv_evento
                        last_changed_by         = lv_usuario
                        last_changed_at         = lv_evento
                        local_last_changed_at   = lv_evento ) TO lt_reembolsos.
      ENDIF.
      APPEND ls_pedido TO lt_pedidos.

      " ---- Pagamento (última tentativa), exceto pedidos ainda sem pagamento
      IF lv_status_pag <> zif_pc_constants=>c_status_pagamento-pendente.
        DATA(lv_aprovado) = xsdbool( lv_status_pag = zif_pc_constants=>c_status_pagamento-aprovado ).
        DATA(lv_ultimos4) = CONV zta_pc_pagamento-ultimos4_digitos( 1000 + ( lv_i * 37 ) MOD 9000 ).
        DATA(lv_bandeira) = COND string( WHEN lv_i MOD 2 = 0 THEN `VISA` ELSE `MASTERCARD` ).

        APPEND VALUE #( pagamento_uuid         = cl_system_uuid=>create_uuid_x16_static( )
                        pedido_uuid            = lv_pedido_uuid
                        metodo_pagamento       = COND #( WHEN lv_i MOD 3 = 0
                                                         THEN zif_pc_constants=>c_metodo_pagamento-debito
                                                         ELSE zif_pc_constants=>c_metodo_pagamento-credito )
                        status_pagamento       = lv_status_pag
                        bandeira_cartao        = lv_bandeira
                        ultimos4_digitos       = lv_ultimos4
                        cartao_mascarado       = |**** **** **** { lv_ultimos4 }|
                        codigo_autorizacao     = COND #( WHEN lv_aprovado = abap_true
                                                         THEN |SIM{ 100000 + ( lv_i * 7919 ) MOD 900000 }| )
                        mensagem_pagamento     = COND #( WHEN lv_aprovado = abap_true
                                                         THEN |Pagamento aprovado (simulação) - { lv_bandeira }.|
                                                         ELSE `Pagamento recusado pela operadora (simulação).` )
                        data_pagamento         = lv_evento
                        created_by             = lv_usuario
                        created_at             = lv_evento
                        last_changed_by        = lv_usuario
                        last_changed_at        = lv_evento
                        local_last_changed_at  = lv_evento ) TO lt_pagamentos.
      ENDIF.

      " ---- Snapshot do cliente/endereço (finalizados e cancelados)
      IF lv_fin = abap_true OR lv_canc = abap_true.
        APPEND VALUE #( snapshot_uuid          = cl_system_uuid=>create_uuid_x16_static( )
                        pedido_uuid            = lv_pedido_uuid
                        cliente_uuid           = ls_cli-cliente_uuid
                        cpf                    = ls_cli-cpf
                        nome                   = ls_cli-nome
                        email                  = ls_cli-email
                        telefone               = ls_cli-telefone
                        genero                 = ls_cli-genero
                        data_nascimento        = ls_cli-data_nascimento
                        cliente_ativo          = ls_cli-cliente_ativo
                        score_cliente          = ls_cli-score_cliente
                        endereco_uuid          = ls_cli-endereco_uuid
                        cep                    = ls_cli-cep
                        logradouro             = ls_cli-logradouro
                        numero                 = ls_cli-numero
                        complemento            = ls_cli-complemento
                        bairro                 = ls_cli-bairro
                        cidade                 = ls_cli-cidade
                        uf                     = ls_cli-uf
                        estado                 = ls_cli-estado
                        endereco_completo      = ls_pedido-endereco_completo
                        motivo_snapshot        = lv_motivo_snap
                        created_by             = lv_usuario
                        created_at             = lv_evento
                        last_changed_by        = lv_usuario
                        last_changed_at        = lv_evento
                        local_last_changed_at  = lv_evento ) TO lt_snap_cli.
      ENDIF.
    ENDDO.

    INSERT zta_pc_pedido    FROM TABLE @lt_pedidos.
    INSERT zta_pc_item_ped  FROM TABLE @lt_itens_ped.
    INSERT zta_pc_pagamento FROM TABLE @lt_pagamentos.
    INSERT zta_pc_reembolso FROM TABLE @lt_reembolsos.
    INSERT zta_pc_snap_cli  FROM TABLE @lt_snap_cli.
    INSERT zta_pc_snap_itm  FROM TABLE @lt_snap_itm.

    " Reflete no estoque as reservas (pedidos em andamento) e baixas (finalizados)
    LOOP AT lt_itens ASSIGNING <ls_item> WHERE alterado = abap_true.
      DATA(lv_disponivel)     = <ls_item>-qtde_estoque - <ls_item>-qtde_reservada.
      DATA(lv_status_estoque) = zcl_pc_util=>calcular_status_estoque( lv_disponivel ).
      UPDATE zta_pc_item
        SET qtde_estoque          = @<ls_item>-qtde_estoque,
            qtde_reservada        = @<ls_item>-qtde_reservada,
            qtde_disponivel       = @lv_disponivel,
            status_estoque        = @lv_status_estoque,
            last_changed_by       = @lv_usuario,
            last_changed_at       = @lv_agora,
            local_last_changed_at = @lv_agora
        WHERE item_uuid = @<ls_item>-item_uuid.
    ENDLOOP.

    io_out->write( |Pedidos de demonstração criados: { lines( lt_pedidos ) }.| ).
    DATA(lt_resumo) = VALUE tt_status( ( lc_ped-criado ) ( lc_ped-aguardando_pagamento )
                                       ( lc_ped-aguardando_aprovacao ) ( lc_ped-finalizado )
                                       ( lc_ped-processar_reembolso ) ( lc_ped-cancelado ) ).
    LOOP AT lt_resumo INTO DATA(lv_resumo).
      io_out->write( |  { lv_resumo }: { contar( it_pedidos = lt_pedidos iv_status = lv_resumo ) }| ).
    ENDLOOP.
    io_out->write( |Solicitações de reembolso pendentes: { lines( lt_reembolsos ) }.| ).
  ENDMETHOD.


  METHOD ts_passado.
    DATA lv_data TYPE d.
    DATA lv_hora TYPE t.

    DATA(lv_utc) = utclong_add( val   = utclong_current( )
                                days  = 0 - iv_dias
                                hours = 0 - iv_horas ).
    CONVERT UTCLONG lv_utc INTO DATE lv_data TIME lv_hora TIME ZONE 'UTC'.
    CONVERT DATE lv_data TIME lv_hora INTO TIME STAMP rv_ts TIME ZONE 'UTC'.
  ENDMETHOD.


  METHOD contar.
    rv_qtd = REDUCE i( INIT n = 0
                       FOR p IN it_pedidos WHERE ( status_pedido = iv_status )
                       NEXT n = n + 1 ).
  ENDMETHOD.

ENDCLASS.
