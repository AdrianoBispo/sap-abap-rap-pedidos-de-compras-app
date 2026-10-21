*"* Test Classes da classe ZCL_PC_UTIL
*"* Regras puras: sem banco, sem RAP, sem chamadas remotas.

CLASS ltcl_digitos_cpf DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS somente_digitos_remove_mascara FOR TESTING.
    METHODS somente_digitos_sem_numeros    FOR TESTING.
    METHODS cpf_valido_sem_mascara         FOR TESTING.
    METHODS cpf_valido_com_mascara         FOR TESTING.
    METHODS cpf_digito_verificador_errado  FOR TESTING.
    METHODS cpf_digitos_repetidos          FOR TESTING.
    METHODS cpf_tamanho_invalido           FOR TESTING.
    METHODS calcula_digitos_verificadores  FOR TESTING.
    METHODS calcula_dv_base_invalida       FOR TESTING.
    METHODS formata_cpf                    FOR TESTING.
    METHODS formata_telefone_11_digitos    FOR TESTING.
    METHODS formata_telefone_10_digitos    FOR TESTING.
ENDCLASS.


CLASS ltcl_digitos_cpf IMPLEMENTATION.

  METHOD somente_digitos_remove_mascara.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>somente_digitos( '529.982.247-25' )
      exp = `52998224725`
      msg = 'Pontos e hífen devem ser removidos' ).
  ENDMETHOD.

  METHOD somente_digitos_sem_numeros.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_pc_util=>somente_digitos( 'sem numeros' )
      msg = 'Texto sem dígitos deve resultar em vazio' ).
  ENDMETHOD.

  METHOD cpf_valido_sem_mascara.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_cpf( '52998224725' )
      exp = abap_true
      msg = 'CPF com dígitos verificadores corretos deve ser válido' ).
  ENDMETHOD.

  METHOD cpf_valido_com_mascara.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_cpf( '111.444.777-35' )
      exp = abap_true
      msg = 'CPF formatado deve ser normalizado antes da validação' ).
  ENDMETHOD.

  METHOD cpf_digito_verificador_errado.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_cpf( '52998224726' )
      exp = abap_false
      msg = 'Último dígito alterado deve invalidar o CPF' ).
  ENDMETHOD.

  METHOD cpf_digitos_repetidos.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_cpf( '11111111111' )
      exp = abap_false
      msg = 'Sequência repetida não é CPF válido' ).
  ENDMETHOD.

  METHOD cpf_tamanho_invalido.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_cpf( '5299822472' )
      exp = abap_false
      msg = 'CPF precisa ter 11 dígitos' ).
  ENDMETHOD.

  METHOD calcula_digitos_verificadores.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>calcular_dv_cpf( '529982247' )
      exp = `52998224725`
      msg = 'Os dois dígitos verificadores devem ser acrescentados à base' ).
  ENDMETHOD.

  METHOD calcula_dv_base_invalida.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_pc_util=>calcular_dv_cpf( '12345' )
      msg = 'Base diferente de 9 dígitos deve devolver vazio' ).
  ENDMETHOD.

  METHOD formata_cpf.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>formatar_cpf( '52998224725' )
      exp = `529.982.247-25`
      msg = 'CPF exibido deve usar a máscara padrão' ).
  ENDMETHOD.

  METHOD formata_telefone_11_digitos.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>formatar_telefone( '11987654321' )
      exp = `(11) 98765-4321`
      msg = 'Celular com 11 dígitos' ).
  ENDMETHOD.

  METHOD formata_telefone_10_digitos.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>formatar_telefone( '1132654321' )
      exp = `(11) 3265-4321`
      msg = 'Fixo com 10 dígitos' ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_email_imagem DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_png  TYPE string VALUE `89504E470D0A1A0A0000000D49484452`.
    CONSTANTS c_jpeg TYPE string VALUE `FFD8FFE000104A46494600010100`.
    CONSTANTS c_webp TYPE string VALUE `524946462A00000057454250565038200000`.

    METHODS email_valido              FOR TESTING.
    METHODS email_sem_arroba          FOR TESTING.
    METHODS email_sem_dominio         FOR TESTING.
    METHODS imagem_vazia_e_valida     FOR TESTING.
    METHODS imagem_png_valida         FOR TESTING.
    METHODS imagem_jpeg_valida        FOR TESTING.
    METHODS imagem_webp_valida        FOR TESTING.
    METHODS imagem_webp_falsificada   FOR TESTING.
    METHODS imagem_mime_nao_permitido FOR TESTING.
    METHODS imagem_extensao_divergente FOR TESTING.
    METHODS imagem_conteudo_falsificado FOR TESTING.
ENDCLASS.


CLASS ltcl_email_imagem IMPLEMENTATION.

  METHOD email_valido.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_email( 'Maria.Souza@Example.COM' )
      exp = abap_true
      msg = 'E-mail válido, inclusive com maiúsculas' ).
  ENDMETHOD.

  METHOD email_sem_arroba.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_email( 'maria.souza.example.com' )
      exp = abap_false
      msg = 'E-mail sem @ é inválido' ).
  ENDMETHOD.

  METHOD email_sem_dominio.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_email( 'maria@example' )
      exp = abap_false
      msg = 'E-mail sem domínio de topo é inválido' ).
  ENDMETHOD.

  METHOD imagem_vazia_e_valida.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_imagem( iv_conteudo     = VALUE xstring( )
                                         iv_mime_type    = ''
                                         iv_nome_arquivo = '' )
      exp = abap_true
      msg = 'Foto é opcional: conteúdo vazio é aceito' ).
  ENDMETHOD.

  METHOD imagem_png_valida.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_imagem( iv_conteudo     = CONV xstring( c_png )
                                         iv_mime_type    = 'image/png'
                                         iv_nome_arquivo = 'cliente.PNG' )
      exp = abap_true
      msg = 'PNG com assinatura correta deve ser aceito' ).
  ENDMETHOD.

  METHOD imagem_jpeg_valida.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_imagem( iv_conteudo     = CONV xstring( c_jpeg )
                                         iv_mime_type    = 'image/jpeg'
                                         iv_nome_arquivo = 'item.jpg' )
      exp = abap_true
      msg = 'JPEG com assinatura correta deve ser aceito' ).
  ENDMETHOD.

  METHOD imagem_webp_valida.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_imagem( iv_conteudo     = CONV xstring( c_webp )
                                         iv_mime_type    = 'image/webp'
                                         iv_nome_arquivo = 'item.WEBP' )
      exp = abap_true
      msg = 'WEBP com assinatura RIFF/WEBP correta deve ser aceito' ).
  ENDMETHOD.

  METHOD imagem_webp_falsificada.
    " MIME diz WEBP, mas os bytes são de um PNG
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_imagem( iv_conteudo     = CONV xstring( c_png )
                                         iv_mime_type    = 'image/webp'
                                         iv_nome_arquivo = 'cliente.webp' )
      exp = abap_false
      msg = 'Assinatura RIFF/WEBP deve bater com o MIME type informado' ).
  ENDMETHOD.

  METHOD imagem_mime_nao_permitido.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_imagem( iv_conteudo     = CONV xstring( c_png )
                                         iv_mime_type    = 'image/gif'
                                         iv_nome_arquivo = 'cliente.gif' )
      exp = abap_false
      msg = 'Somente JPEG, PNG e WEBP são aceitos' ).
  ENDMETHOD.

  METHOD imagem_extensao_divergente.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_imagem( iv_conteudo     = CONV xstring( c_png )
                                         iv_mime_type    = 'image/png'
                                         iv_nome_arquivo = 'cliente.exe' )
      exp = abap_false
      msg = 'Extensão deve ser compatível com o MIME type' ).
  ENDMETHOD.

  METHOD imagem_conteudo_falsificado.
    " MIME diz PNG, mas os bytes são de um JPEG
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>validar_imagem( iv_conteudo     = CONV xstring( c_jpeg )
                                         iv_mime_type    = 'image/png'
                                         iv_nome_arquivo = 'cliente.png' )
      exp = abap_false
      msg = 'Assinatura binária deve bater com o MIME type informado' ).
  ENDMETHOD.

ENDCLASS.


*"* ---------------------------------------------------------------------------
*"* Testes de integração dos BOs Pedido / Item / Reembolso (EML).
*"* Cada teste semeia seus próprios dados por INSERT (o AUnit desfaz a gravação
*"* ao terminar) e roda no máximo um Edit por teste: um rascunho sobrevive ao
*"* Activate dentro da mesma LUW. Mantenha estes testes em sincronia com as
*"* regras de negócio: ao ajustar uma funcionalidade, ajuste o teste dela.
*"* ---------------------------------------------------------------------------
*"* Base: dados de teste e atalhos de EML compartilhados pelas classes abaixo.
CLASS lcl_base_fluxo DEFINITION ABSTRACT.

  PROTECTED SECTION.
    TYPES: BEGIN OF ty_ped,
             status    TYPE zta_pc_pedido-status_pedido,
             pagamento TYPE zta_pc_pedido-status_pagamento,
             numero    TYPE zta_pc_pedido-numero_pedido,
             total     TYPE zta_pc_pedido-valor_total,
             motivo    TYPE zta_pc_pedido-motivo_cancelamento,
             encerrado TYPE zta_pc_pedido-pedido_encerrado,
             nao_fin   TYPE zta_pc_pedido-pedido_nao_finalizado,
             nao_canc  TYPE zta_pc_pedido-pedido_nao_cancelado,
           END OF ty_ped.
    TYPES: BEGIN OF ty_linha,
             item TYPE sysuuid_x16,
             qtde TYPE i,
           END OF ty_linha,
           tt_linha TYPE STANDARD TABLE OF ty_linha WITH EMPTY KEY.
    METHODS semear_cliente RETURNING VALUE(rv_cliente) TYPE sysuuid_x16.
    METHODS semear_item
      IMPORTING iv_sku        TYPE csequence
                iv_preco      TYPE zta_pc_item-preco_unitario
                iv_reservada  TYPE i DEFAULT 0
      RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.
    METHODS semear_pedido
      IMPORTING iv_cliente       TYPE sysuuid_x16
                it_linhas        TYPE tt_linha
                iv_status        TYPE zta_pc_pedido-status_pedido
                                 DEFAULT zif_pc_constants=>c_status_pedido-aberto
                iv_pagamento     TYPE zta_pc_pedido-status_pagamento
                                 DEFAULT zif_pc_constants=>c_status_pagamento-pendente
      RETURNING VALUE(rv_pedido) TYPE sysuuid_x16.
    METHODS editar
      IMPORTING iv_pedido TYPE sysuuid_x16.
    METHODS reservado
      IMPORTING iv_uuid       TYPE sysuuid_x16
      RETURNING VALUE(rv_qtd) TYPE i.
    METHODS salvar
      IMPORTING iv_pedido TYPE sysuuid_x16
      RETURNING VALUE(rv_msg) TYPE string.
    METHODS estoque_fisico
      IMPORTING iv_uuid       TYPE sysuuid_x16
      RETURNING VALUE(rv_qtd) TYPE i.
    METHODS ler_pedido
      IMPORTING iv_pedido        TYPE sysuuid_x16
      RETURNING VALUE(rs_pedido) TYPE ty_ped.
    METHODS criar_rascunho
      IMPORTING iv_cliente       TYPE sysuuid_x16
                iv_item          TYPE sysuuid_x16
                iv_qtde          TYPE i
      RETURNING VALUE(rv_pedido) TYPE sysuuid_x16.
    METHODS pagar
      IMPORTING iv_pedido        TYPE sysuuid_x16
                iv_cvv           TYPE csequence DEFAULT '123'
      RETURNING VALUE(rv_falhou) TYPE abap_boolean.
    METHODS aprovar_pedido
      IMPORTING iv_pedido        TYPE sysuuid_x16
      RETURNING VALUE(rv_falhou) TYPE abap_boolean.
    METHODS cancelar
      IMPORTING iv_pedido        TYPE sysuuid_x16
                iv_motivo        TYPE csequence DEFAULT 'QA'
      RETURNING VALUE(rv_falhou) TYPE abap_boolean.
    METHODS semear_pagamento
      IMPORTING iv_pedido TYPE sysuuid_x16
                iv_status TYPE zta_pc_pagamento-status_pagamento.
    METHODS semear_reembolso
      IMPORTING iv_pedido         TYPE sysuuid_x16
                iv_cliente        TYPE sysuuid_x16
                iv_status_anterior TYPE zta_pc_reembolso-status_pedido_anterior
      RETURNING VALUE(rv_reembolso) TYPE sysuuid_x16.
    METHODS decidir_reembolso
      IMPORTING iv_reembolso     TYPE sysuuid_x16
                iv_aprovar       TYPE abap_boolean
                iv_motivo        TYPE csequence DEFAULT 'QA'
      RETURNING VALUE(rv_falhou) TYPE abap_boolean.
    METHODS status_reembolso
      IMPORTING iv_reembolso     TYPE sysuuid_x16
      RETURNING VALUE(rv_status) TYPE zta_pc_reembolso-status_reembolso.
ENDCLASS.


*"* Edição dos itens de pedido ABERTO: a reserva de estoque acompanha a diferença
*"* (alterar quantidade, incluir, remover item e cancelar o pedido).
CLASS ltcl_edicao_pedido DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_fluxo
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS editar_altera_e_inclui FOR TESTING.
    METHODS editar_remove_item FOR TESTING.
    METHODS editar_so_pedido_aberto FOR TESTING.
ENDCLASS.


*"* Registro do pedido (Save do rascunho): status inicial, número, total,
*"* reserva de estoque e bloqueio por falta de estoque.
CLASS ltcl_registro_pedido DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_fluxo
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS registro_reserva_e_status FOR TESTING.
    METHODS registro_nao_sobre_reserva FOR TESTING.
ENDCLASS.


*"* Ciclo de vida: pagamento, aprovação, cancelamento (com e sem pagamento).
CLASS ltcl_ciclo_pedido DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_fluxo
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS pagamento_aprovado FOR TESTING.
    METHODS pagamento_recusado FOR TESTING.
    METHODS aprovar_sem_pagamento_falha FOR TESTING.
    METHODS aprovar_finaliza_e_baixa FOR TESTING.
    METHODS cancelar_aberto_libera FOR TESTING.
    METHODS cancelar_exige_motivo FOR TESTING.
    METHODS cancelar_pago_pede_reembolso FOR TESTING.
ENDCLASS.


*"* Decisão do reembolso (BO Reembolso aciona o BO Pedido na mesma LUW).
CLASS ltcl_reembolso DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_fluxo
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS aprovar_cancela_e_devolve FOR TESTING.
    METHODS rejeitar_sem_motivo_falha FOR TESTING.
    METHODS rejeitar_retoma_pedido FOR TESTING.
ENDCLASS.


CLASS lcl_base_fluxo IMPLEMENTATION.

  METHOD reservado.
    READ ENTITIES OF zr_pc_item
      ENTITY Item
        FIELDS ( QtdeReservada )
        WITH VALUE #( ( ItemUUID = iv_uuid %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_item).
    IF lt_item IS NOT INITIAL.
      rv_qtd = lt_item[ 1 ]-QtdeReservada.
    ENDIF.
  ENDMETHOD.

  METHOD salvar.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE Prepare FROM VALUE #( ( %key-PedidoUUID = iv_pedido ) )
      FAILED DATA(ls_failed_prep)
      REPORTED DATA(ls_reported_prep).
    LOOP AT ls_reported_prep-pedido INTO DATA(ls_rp) WHERE %msg IS BOUND.
      rv_msg = |{ rv_msg } / { ls_rp-%msg->if_message~get_text( ) }|.
    ENDLOOP.
    cl_abap_unit_assert=>assert_initial( act = ls_failed_prep-pedido msg = |Prepare falhou: { rv_msg }| ).

    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE Activate FROM VALUE #( ( %cid = 'ACT' %key-PedidoUUID = iv_pedido ) )
      FAILED DATA(ls_failed_act)
      REPORTED DATA(ls_reported_act).
    LOOP AT ls_reported_act-pedido INTO DATA(ls_ra) WHERE %msg IS BOUND.
      rv_msg = |{ rv_msg } / { ls_ra-%msg->if_message~get_text( ) }|.
    ENDLOOP.
    cl_abap_unit_assert=>assert_initial( act = ls_failed_act-pedido msg = |Activate falhou: { rv_msg }| ).
  ENDMETHOD.

  METHOD semear_cliente.
    rv_cliente = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zta_pc_cliente FROM @( VALUE #( cliente_uuid = rv_cliente cpf = '12345678909' nome = 'QA Edicao'
                                           email = 'qa@teste.com' telefone = '11999999999'
                                           cliente_ativo = abap_true ) ).
    INSERT zta_pc_endereco FROM @( VALUE #( endereco_uuid = cl_system_uuid=>create_uuid_x16_static( )
                                            cep = '01310100' cliente_uuid = rv_cliente logradouro = 'Av Teste'
                                            numero = '1' bairro = 'Centro' cidade = 'Sao Paulo' uf = 'SP'
                                            estado = 'Sao Paulo' cep_status = 'V'
                                            endereco_principal = abap_true ) ).
  ENDMETHOD.

  METHOD semear_item.
    rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zta_pc_item FROM @( VALUE #( item_uuid = rv_uuid sku = iv_sku nome = iv_sku categoria = 'OUTROS'
                                        qtde_estoque = 100 qtde_reservada = iv_reservada
                                        qtde_disponivel = 100 - iv_reservada status_estoque = 'EM_ESTOQUE'
                                        currency = 'BRL' preco_unitario = iv_preco item_ativo = abap_true ) ).
  ENDMETHOD.

  METHOD semear_pedido.
    " Pedido ativo ABERTO já gravado (como depois do primeiro Save)
    rv_pedido = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zta_pc_pedido FROM @( VALUE #( pedido_uuid = rv_pedido numero_pedido = '9999999999'
                                          cliente_uuid = iv_cliente status_pedido = iv_status
                                          status_pagamento = iv_pagamento
                                          currency = 'BRL' pedido_ativo_sem_hist = abap_true
                                          pedido_nao_finalizado = abap_true pedido_nao_cancelado = abap_true ) ).
    LOOP AT it_linhas INTO DATA(ls_l).
      INSERT zta_pc_item_ped FROM @( VALUE #( item_pedido_uuid = cl_system_uuid=>create_uuid_x16_static( )
                                              pedido_uuid = rv_pedido item_uuid = ls_l-item qtde_item_pedido = ls_l-qtde
                                              currency = 'BRL' preco_unitario_snap = '10.00'
                                              valor_total = ls_l-qtde * '10.00' ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD editar.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE Edit FROM VALUE #( ( %cid = 'ED' %key-PedidoUUID = iv_pedido ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_rep).
    DATA(lv_txt) = ``.
    LOOP AT ls_rep-pedido INTO DATA(ls_r) WHERE %msg IS BOUND.
      lv_txt = |{ lv_txt } / { ls_r-%msg->if_message~get_text( ) }|.
    ENDLOOP.
    cl_abap_unit_assert=>assert_initial( act = ls_failed-pedido msg = |Edit falhou: { lv_txt }| ).
  ENDMETHOD.

  METHOD estoque_fisico.
    READ ENTITIES OF zr_pc_item
      ENTITY Item
        FIELDS ( QtdeEstoque )
        WITH VALUE #( ( ItemUUID = iv_uuid %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_item).
    IF lt_item IS NOT INITIAL.
      rv_qtd = lt_item[ 1 ]-QtdeEstoque.
    ENDIF.
  ENDMETHOD.

  METHOD ler_pedido.
    READ ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        ALL FIELDS WITH VALUE #( ( PedidoUUID = iv_pedido %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_ped).
    CHECK lt_ped IS NOT INITIAL.
    DATA(ls_ped) = lt_ped[ 1 ].
    rs_pedido = VALUE #( status    = ls_ped-StatusPedido
                         pagamento = ls_ped-StatusPagamento
                         numero    = ls_ped-NumeroPedido
                         total     = ls_ped-ValorTotal
                         motivo    = ls_ped-MotivoCancelamento
                         encerrado = ls_ped-PedidoEncerrado
                         nao_fin   = ls_ped-PedidoNaoFinalizado
                         nao_canc  = ls_ped-PedidoNaoCancelado ).
  ENDMETHOD.

  METHOD criar_rascunho.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        CREATE FIELDS ( ClienteUUID )
        WITH VALUE #( ( %cid = 'P1' %is_draft = if_abap_behv=>mk-on ClienteUUID = iv_cliente ) )
      ENTITY Pedido
        CREATE BY \_Itens FIELDS ( ItemUUID QtdeItemPedido )
        WITH VALUE #( ( %cid_ref = 'P1' %is_draft = if_abap_behv=>mk-on
                        %target  = VALUE #( ( %cid = 'I1' %is_draft = if_abap_behv=>mk-on
                                              ItemUUID = iv_item QtdeItemPedido = iv_qtde ) ) ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao criar o rascunho' ).
    rv_pedido = ls_mapped-pedido[ 1 ]-PedidoUUID.
  ENDMETHOD.

  METHOD pagar.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE SimularPagamento FROM VALUE #( ( %key-PedidoUUID = iv_pedido %is_draft = if_abap_behv=>mk-off
                                                 %param-MetodoPagamento = zif_pc_constants=>c_metodo_pagamento-credito
                                                 %param-NumeroCartao    = '4111111111111111'
                                                 %param-Validade        = '12/99'
                                                 %param-Cvv             = iv_cvv ) )
      FAILED DATA(ls_failed).
    rv_falhou = xsdbool( ls_failed-pedido IS NOT INITIAL ).
  ENDMETHOD.

  METHOD aprovar_pedido.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE AprovarPedido FROM VALUE #( ( %key-PedidoUUID = iv_pedido %is_draft = if_abap_behv=>mk-off ) )
      FAILED DATA(ls_failed).
    rv_falhou = xsdbool( ls_failed-pedido IS NOT INITIAL ).
  ENDMETHOD.

  METHOD cancelar.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE CancelarPedido FROM VALUE #( ( %key-PedidoUUID = iv_pedido %is_draft = if_abap_behv=>mk-off
                                               %param-MotivoCancelamento = iv_motivo ) )
      FAILED DATA(ls_failed).
    rv_falhou = xsdbool( ls_failed-pedido IS NOT INITIAL ).
  ENDMETHOD.

  METHOD semear_pagamento.
    INSERT zta_pc_pagamento FROM @( VALUE #( pagamento_uuid   = cl_system_uuid=>create_uuid_x16_static( )
                                             pedido_uuid      = iv_pedido
                                             metodo_pagamento = zif_pc_constants=>c_metodo_pagamento-credito
                                             status_pagamento = iv_status ) ).
  ENDMETHOD.

  METHOD semear_reembolso.
    rv_reembolso = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zta_pc_reembolso FROM @( VALUE #( reembolso_uuid        = rv_reembolso
                                             pedido_uuid           = iv_pedido
                                             numero_pedido         = '9999999999'
                                             cliente_uuid          = iv_cliente
                                             status_reembolso      = zif_pc_constants=>c_status_reembolso-pendente
                                             status_pedido_anterior = iv_status_anterior
                                             currency              = 'BRL'
                                             valor_reembolso       = '20.00'
                                             motivo_solicitacao    = 'QA' ) ).
  ENDMETHOD.

  METHOD decidir_reembolso.
    IF iv_aprovar = abap_true.
      MODIFY ENTITIES OF zr_pc_reembolso
        ENTITY Reembolso
          EXECUTE AprovarReembolso FROM VALUE #( ( %key-ReembolsoUUID = iv_reembolso
                                                   %param-MotivoDecisao = iv_motivo ) )
        FAILED DATA(ls_failed_apr).
      rv_falhou = xsdbool( ls_failed_apr-reembolso IS NOT INITIAL ).
    ELSE.
      MODIFY ENTITIES OF zr_pc_reembolso
        ENTITY Reembolso
          EXECUTE RejeitarReembolso FROM VALUE #( ( %key-ReembolsoUUID = iv_reembolso
                                                    %param-MotivoDecisao = iv_motivo ) )
        FAILED DATA(ls_failed_rej).
      rv_falhou = xsdbool( ls_failed_rej-reembolso IS NOT INITIAL ).
    ENDIF.
  ENDMETHOD.

  METHOD status_reembolso.
    READ ENTITIES OF zr_pc_reembolso
      ENTITY Reembolso
        FIELDS ( StatusReembolso )
        WITH VALUE #( ( ReembolsoUUID = iv_reembolso ) )
      RESULT DATA(lt_reemb).
    IF lt_reemb IS NOT INITIAL.
      rv_status = lt_reemb[ 1 ]-StatusReembolso.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_edicao_pedido IMPLEMENTATION.

  METHOD editar_altera_e_inclui.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a) = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_b) = semear_item( iv_sku = 'SKU-QAB-0000000001' iv_preco = '20.00' ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli it_linhas = VALUE #( ( item = lv_a qtde = 2 ) ) ).

    editar( lv_ped ).
    READ ENTITIES OF zr_pc_pedido
      ENTITY Pedido BY \_Itens FIELDS ( ItemUUID QtdeItemPedido )
        WITH VALUE #( ( PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-on ) )
      RESULT DATA(lt_it).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_it ) exp = 1 msg = 'Rascunho de edição sem o item' ).
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY ItemPedido
        UPDATE FIELDS ( QtdeItemPedido )
        WITH VALUE #( ( %tky = lt_it[ 1 ]-%tky QtdeItemPedido = 5 ) )
      ENTITY Pedido
        CREATE BY \_Itens FIELDS ( ItemUUID QtdeItemPedido )
        WITH VALUE #( ( %tky = VALUE #( PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-on )
                        %target = VALUE #( ( %cid = 'I2' %is_draft = if_abap_behv=>mk-on
                                             ItemUUID = lv_b QtdeItemPedido = 1 ) ) ) ).
    DATA(lv_msg) = salvar( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 5 msg = |A deveria ter 5 reservados. { lv_msg }| ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_b ) exp = 1 msg = |B deveria ter 1 reservado. { lv_msg }| ).

    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE CancelarPedido FROM VALUE #( ( %key-PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-off
                                               %param-MotivoCancelamento = 'QA' ) )
      FAILED DATA(ls_failed_can).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_can-pedido msg = 'CancelarPedido falhou' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 0 msg = 'Cancelar deve liberar A' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_b ) exp = 0 msg = 'Cancelar deve liberar B' ).
  ENDMETHOD.

  METHOD editar_remove_item.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a) = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_b) = semear_item( iv_sku = 'SKU-QAB-0000000001' iv_preco = '20.00' iv_reservada = 1 ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli
                                  it_linhas  = VALUE #( ( item = lv_a qtde = 2 ) ( item = lv_b qtde = 1 ) ) ).

    editar( lv_ped ).
    READ ENTITIES OF zr_pc_pedido
      ENTITY Pedido BY \_Itens FIELDS ( ItemUUID QtdeItemPedido )
        WITH VALUE #( ( PedidoUUID = lv_ped %is_draft = if_abap_behv=>mk-on ) )
      RESULT DATA(lt_it).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_it ) exp = 2 msg = 'Rascunho de edição deveria ter 2 itens' ).
    DATA(ls_b) = lt_it[ ItemUUID = lv_b ].
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY ItemPedido
        DELETE FROM VALUE #( ( %tky = ls_b-%tky ) ).
    DATA(lv_msg) = salvar( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 2 msg = |A deveria seguir com 2. { lv_msg }| ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_b ) exp = 0 msg = |B deveria ter sido liberado. { lv_msg }| ).
  ENDMETHOD.

  METHOD editar_so_pedido_aberto.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente   = lv_cli
                                  it_linhas    = VALUE #( ( item = lv_a qtde = 2 ) )
                                  iv_status    = zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                  iv_pagamento = zif_pc_constants=>c_status_pagamento-aprovado ).

    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE Edit FROM VALUE #( ( %cid = 'ED' %key-PedidoUUID = lv_ped ) )
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-pedido
                                             msg = 'Só pedido ABERTO pode ser editado' ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_registro_pedido IMPLEMENTATION.

  METHOD registro_reserva_e_status.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' ).

    DATA(lv_ped) = criar_rascunho( iv_cliente = lv_cli iv_item = lv_a iv_qtde = 3 ).
    DATA(lv_msg) = salvar( lv_ped ).

    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-status
                                        exp = zif_pc_constants=>c_status_pedido-aberto
                                        msg = |Pedido registrado deve ficar ABERTO. { lv_msg }| ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-pagamento
                                        exp = zif_pc_constants=>c_status_pagamento-pendente
                                        msg = 'Pagamento deve iniciar PENDENTE' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_ped-numero msg = 'Número do pedido não gerado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-encerrado exp = abap_false msg = 'Aberto não é encerrado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-nao_fin exp = abap_true msg = 'Seção Finalização deve ficar oculta' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-nao_canc exp = abap_true msg = 'Seção Cancelamento deve ficar oculta' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 3 msg = |Registro deve reservar 3. { lv_msg }| ).
  ENDMETHOD.

  METHOD registro_nao_sobre_reserva.
    " Mesmo que o Save chegue ao Activate sem a validação da tela, a reserva
    " nunca ultrapassa o estoque: tudo ou nada.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' ).

    DATA(lv_ped) = criar_rascunho( iv_cliente = lv_cli iv_item = lv_a iv_qtde = 101 ).
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE Activate FROM VALUE #( ( %cid = 'ACT' %key-PedidoUUID = lv_ped ) ).

    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 0
                                        msg = 'Quantidade acima do disponível não pode ser reservada' ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_ciclo_pedido IMPLEMENTATION.

  METHOD pagamento_aprovado.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli it_linhas = VALUE #( ( item = lv_a qtde = 2 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = pagar( lv_ped ) exp = abap_false msg = 'Efetuar Pagamento falhou' ).

    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-status
                                        exp = zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                        msg = 'Pagamento aprovado deve levar a AGUARDANDO_APROVACAO' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-pagamento
                                        exp = zif_pc_constants=>c_status_pagamento-aprovado
                                        msg = 'Pagamento deve ficar APROVADO' ).
  ENDMETHOD.

  METHOD pagamento_recusado.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli it_linhas = VALUE #( ( item = lv_a qtde = 2 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = pagar( iv_pedido = lv_ped iv_cvv = '000' ) exp = abap_false
                                        msg = 'Recusa não é erro técnico' ).

    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-status
                                        exp = zif_pc_constants=>c_status_pedido-aberto
                                        msg = 'Pagamento recusado mantém o pedido ABERTO' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-pagamento
                                        exp = zif_pc_constants=>c_status_pagamento-recusado
                                        msg = 'Pagamento deve ficar RECUSADO' ).
  ENDMETHOD.

  METHOD aprovar_sem_pagamento_falha.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli it_linhas = VALUE #( ( item = lv_a qtde = 2 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = aprovar_pedido( lv_ped ) exp = abap_true
                                        msg = 'Aprovar pedido sem pagamento deve falhar' ).
    cl_abap_unit_assert=>assert_equals( act = ler_pedido( lv_ped )-status
                                        exp = zif_pc_constants=>c_status_pedido-aberto msg = 'Status não deve mudar' ).
  ENDMETHOD.

  METHOD aprovar_finaliza_e_baixa.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli it_linhas = VALUE #( ( item = lv_a qtde = 2 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = pagar( lv_ped ) exp = abap_false msg = 'Efetuar Pagamento falhou' ).
    cl_abap_unit_assert=>assert_equals( act = aprovar_pedido( lv_ped ) exp = abap_false msg = 'Aprovar pedido falhou' ).

    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-status
                                        exp = zif_pc_constants=>c_status_pedido-finalizado msg = 'Deve ficar FINALIZADO' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-encerrado exp = abap_true msg = 'Finalizado é encerrado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-nao_fin exp = abap_false msg = 'Seção Finalização deve aparecer' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-nao_canc exp = abap_true msg = 'Seção Cancelamento deve ficar oculta' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 0 msg = 'Baixa deve zerar a reserva' ).
    cl_abap_unit_assert=>assert_equals( act = estoque_fisico( lv_a ) exp = 98 msg = 'Baixa deve reduzir o estoque físico' ).
  ENDMETHOD.

  METHOD cancelar_aberto_libera.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli it_linhas = VALUE #( ( item = lv_a qtde = 2 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = cancelar( lv_ped ) exp = abap_false msg = 'Cancelar falhou' ).

    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-status
                                        exp = zif_pc_constants=>c_status_pedido-cancelado msg = 'Deve ficar CANCELADO' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-encerrado exp = abap_true msg = 'Cancelado é encerrado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-nao_canc exp = abap_false msg = 'Seção Cancelamento deve aparecer' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-nao_fin exp = abap_true msg = 'Seção Finalização deve ficar oculta' ).
    cl_abap_unit_assert=>assert_equals( act = condense( ls_ped-motivo ) exp = `QA` msg = 'Motivo do cancelamento' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 0 msg = 'Cancelar deve liberar a reserva' ).
  ENDMETHOD.

  METHOD cancelar_exige_motivo.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli it_linhas = VALUE #( ( item = lv_a qtde = 2 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = cancelar( iv_pedido = lv_ped iv_motivo = `` ) exp = abap_true
                                        msg = 'Cancelar sem motivo deve falhar' ).
    cl_abap_unit_assert=>assert_equals( act = ler_pedido( lv_ped )-status
                                        exp = zif_pc_constants=>c_status_pedido-aberto msg = 'Status não deve mudar' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 2 msg = 'Reserva deve continuar' ).
  ENDMETHOD.

  METHOD cancelar_pago_pede_reembolso.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente = lv_cli it_linhas = VALUE #( ( item = lv_a qtde = 2 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = pagar( lv_ped ) exp = abap_false msg = 'Efetuar Pagamento falhou' ).
    cl_abap_unit_assert=>assert_equals( act = cancelar( lv_ped ) exp = abap_false msg = 'Cancelar pedido pago falhou' ).

    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-status
                                        exp = zif_pc_constants=>c_status_pedido-processando_reembolso
                                        msg = 'Pedido pago cancelado vai para PROCESSANDO_REEMBOLSO' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-pagamento
                                        exp = zif_pc_constants=>c_status_pagamento-aprovado
                                        msg = 'Pagamento segue APROVADO até a decisão' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 2
                                        msg = 'Estoque segue reservado até a decisão do reembolso' ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_reembolso IMPLEMENTATION.

  METHOD aprovar_cancela_e_devolve.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente   = lv_cli
                                  it_linhas    = VALUE #( ( item = lv_a qtde = 2 ) )
                                  iv_status    = zif_pc_constants=>c_status_pedido-processando_reembolso
                                  iv_pagamento = zif_pc_constants=>c_status_pagamento-aprovado ).
    semear_pagamento( iv_pedido = lv_ped iv_status = zif_pc_constants=>c_status_pagamento-aprovado ).
    DATA(lv_reemb) = semear_reembolso( iv_pedido          = lv_ped
                                       iv_cliente         = lv_cli
                                       iv_status_anterior = zif_pc_constants=>c_status_pedido-aguardando_aprovacao ).

    cl_abap_unit_assert=>assert_equals( act = decidir_reembolso( iv_reembolso = lv_reemb iv_aprovar = abap_true )
                                        exp = abap_false msg = 'Aprovar reembolso falhou' ).

    DATA(ls_ped) = ler_pedido( lv_ped ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-status
                                        exp = zif_pc_constants=>c_status_pedido-cancelado msg = 'Pedido deve ficar CANCELADO' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ped-pagamento
                                        exp = zif_pc_constants=>c_status_pagamento-devolvido msg = 'Pagamento deve ficar DEVOLVIDO' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 0 msg = 'Reserva deve ser liberada' ).
    cl_abap_unit_assert=>assert_equals( act = status_reembolso( lv_reemb )
                                        exp = zif_pc_constants=>c_status_reembolso-aprovado msg = 'Reembolso deve ficar APROVADO' ).
  ENDMETHOD.

  METHOD rejeitar_sem_motivo_falha.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente   = lv_cli
                                  it_linhas    = VALUE #( ( item = lv_a qtde = 2 ) )
                                  iv_status    = zif_pc_constants=>c_status_pedido-processando_reembolso
                                  iv_pagamento = zif_pc_constants=>c_status_pagamento-aprovado ).
    DATA(lv_reemb) = semear_reembolso( iv_pedido          = lv_ped
                                       iv_cliente         = lv_cli
                                       iv_status_anterior = zif_pc_constants=>c_status_pedido-aguardando_aprovacao ).

    cl_abap_unit_assert=>assert_equals( act = decidir_reembolso( iv_reembolso = lv_reemb iv_aprovar = abap_false
                                                                 iv_motivo = `` )
                                        exp = abap_true msg = 'Rejeitar sem motivo deve falhar' ).
    cl_abap_unit_assert=>assert_equals( act = status_reembolso( lv_reemb )
                                        exp = zif_pc_constants=>c_status_reembolso-pendente msg = 'Reembolso segue PENDENTE' ).
  ENDMETHOD.

  METHOD rejeitar_retoma_pedido.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_a)   = semear_item( iv_sku = 'SKU-QAA-0000000001' iv_preco = '10.00' iv_reservada = 2 ).
    DATA(lv_ped) = semear_pedido( iv_cliente   = lv_cli
                                  it_linhas    = VALUE #( ( item = lv_a qtde = 2 ) )
                                  iv_status    = zif_pc_constants=>c_status_pedido-processando_reembolso
                                  iv_pagamento = zif_pc_constants=>c_status_pagamento-aprovado ).
    DATA(lv_reemb) = semear_reembolso( iv_pedido          = lv_ped
                                       iv_cliente         = lv_cli
                                       iv_status_anterior = zif_pc_constants=>c_status_pedido-aguardando_aprovacao ).

    cl_abap_unit_assert=>assert_equals( act = decidir_reembolso( iv_reembolso = lv_reemb iv_aprovar = abap_false )
                                        exp = abap_false msg = 'Rejeitar reembolso falhou' ).

    cl_abap_unit_assert=>assert_equals( act = ler_pedido( lv_ped )-status
                                        exp = zif_pc_constants=>c_status_pedido-aguardando_aprovacao
                                        msg = 'Pedido volta ao status anterior' ).
    cl_abap_unit_assert=>assert_equals( act = status_reembolso( lv_reemb )
                                        exp = zif_pc_constants=>c_status_reembolso-rejeitado msg = 'Reembolso deve ficar REJEITADO' ).
    cl_abap_unit_assert=>assert_equals( act = reservado( lv_a ) exp = 2 msg = 'Reserva deve continuar' ).
  ENDMETHOD.

ENDCLASS.


*"* Persistência do cadastro de endereços do cliente (save real com COMMIT ENTITIES).
*"* Usa test doubles das tabelas, por isso o COMMIT é permitido e o AUnit não grava
*"* dados reais. Cobre o dump RAISE_SHORTDUMP "UPDATE returned unexpected sy-subrc 4"
*"* em ZTA_PC_ENDERECO: a chave da tabela precisa ser igual à chave da entidade.
CLASS ltcl_persistencia_endereco DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA go_cds TYPE REF TO if_cds_test_environment.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS semear
      EXPORTING ev_cliente  TYPE sysuuid_x16
                ev_endereco TYPE sysuuid_x16.
    METHODS contar_enderecos
      IMPORTING iv_cliente    TYPE sysuuid_x16
      RETURNING VALUE(rv_qtd) TYPE i.
    METHODS endereco_novo_ativo FOR TESTING.
    METHODS endereco_novo_rascunho FOR TESTING.
    METHODS cep_gravado_somente_leitura FOR TESTING.
    METHODS semear_dois_enderecos
      EXPORTING ev_cliente TYPE sysuuid_x16
                ev_end1    TYPE sysuuid_x16
                ev_end2    TYPE sysuuid_x16.
    METHODS principal_endereco_ativo FOR TESTING.
    METHODS principal_endereco_rascunho FOR TESTING.
    METHODS numero_endereco_rascunho FOR TESTING.
ENDCLASS.


CLASS ltcl_persistencia_endereco IMPLEMENTATION.

  METHOD class_setup.
    " CDS: leitura e gravação do BO passam pelos doubles; tabelas de rascunho: SQL double
    go_cds = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_PC_CLIENTE' )
                                         ( i_for_entity = 'ZR_PC_ENDERECO' ) ) ).
    go_env = cl_osql_test_environment=>create(
               i_dependency_list = VALUE #( ( 'ZTA_PC_CLIENTE_D' ) ( 'ZTA_PC_ENDEREC_D' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_cds->destroy( ).
    go_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    go_cds->clear_doubles( ).
    go_env->clear_doubles( ).
  ENDMETHOD.

  METHOD semear.
    " Cliente com um endereço principal (CEP 01310100) e um segundo cliente cujo
    " endereço validado (CEP 20040020) alimenta a busca local da determination
    " PreencherEnderecoViaCep (assim o teste não depende do ViaCEP).
    ev_cliente  = cl_system_uuid=>create_uuid_x16_static( ).
    ev_endereco = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(lv_outro) = cl_system_uuid=>create_uuid_x16_static( ).
    DATA lt_cli TYPE STANDARD TABLE OF zta_pc_cliente WITH EMPTY KEY.
    DATA lt_end TYPE STANDARD TABLE OF zta_pc_endereco WITH EMPTY KEY.
    lt_cli = VALUE #( ( client = sy-mandt cliente_uuid = ev_cliente cpf = '12345678909' nome = 'Cliente QA'
                        email = 'qa@teste.com' telefone = '11999999999' data_nascimento = '19900101'
                        cliente_ativo = abap_true )
                      ( client = sy-mandt cliente_uuid = lv_outro cpf = '52998224725' nome = 'Outro QA'
                        email = 'outro@teste.com' telefone = '11988888888' data_nascimento = '19900101'
                        cliente_ativo = abap_true ) ).
    lt_end = VALUE #( ( client = sy-mandt endereco_uuid = ev_endereco cep = '01310100' cliente_uuid = ev_cliente
                        logradouro = 'Av Paulista' numero = '1' bairro = 'Bela Vista' cidade = 'Sao Paulo'
                        uf = 'SP' estado = 'Sao Paulo' cep_status = 'V' endereco_principal = abap_true )
                      ( client = sy-mandt endereco_uuid = cl_system_uuid=>create_uuid_x16_static( ) cep = '20040020'
                        cliente_uuid = lv_outro logradouro = 'Rua da Assembleia' numero = '2'
                        bairro = 'Centro' cidade = 'Rio de Janeiro' uf = 'RJ' estado = 'Rio de Janeiro'
                        cep_status = 'V' endereco_principal = abap_true ) ).
    go_cds->insert_test_data( lt_cli ).
    go_cds->insert_test_data( lt_end ).
  ENDMETHOD.

  METHOD contar_enderecos.
    SELECT COUNT(*) FROM zta_pc_endereco WHERE cliente_uuid = @iv_cliente INTO @rv_qtd.
  ENDMETHOD.

  METHOD endereco_novo_ativo.
    semear( IMPORTING ev_cliente = DATA(lv_cli) ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        CREATE BY \_Endereco FIELDS ( Cep Numero )
        WITH VALUE #( ( %tky    = VALUE #( ClienteUUID = lv_cli %is_draft = if_abap_behv=>mk-off )
                        %target = VALUE #( ( %cid = 'E1' %is_draft = if_abap_behv=>mk-off
                                             Cep = '20040020' Numero = '10' ) ) ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao criar o endereço' ).

    COMMIT ENTITIES RESPONSE OF zr_pc_cliente FAILED DATA(ls_failed_c) REPORTED DATA(ls_reported_c).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_c msg = 'COMMIT falhou' ).
    cl_abap_unit_assert=>assert_equals( act = contar_enderecos( lv_cli ) exp = 2
                                        msg = 'Cliente deveria ter 2 endereços' ).
  ENDMETHOD.

  METHOD endereco_novo_rascunho.
    semear( IMPORTING ev_cliente = DATA(lv_cli) ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Edit FROM VALUE #( ( %cid = 'ED' %key-ClienteUUID = lv_cli ) )
      FAILED DATA(ls_failed_ed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_ed
                                         msg = |Edit falhou. causa={ COND string( WHEN ls_failed_ed-cliente IS NOT INITIAL THEN |{ ls_failed_ed-cliente[ 1 ]-%fail-cause }| ) }| ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        CREATE BY \_Endereco FIELDS ( Cep Numero )
        WITH VALUE #( ( %tky    = VALUE #( ClienteUUID = lv_cli %is_draft = if_abap_behv=>mk-on )
                        %target = VALUE #( ( %cid = 'E1' %is_draft = if_abap_behv=>mk-on
                                             Cep = '20040020' Numero = '10' ) ) ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao criar o endereço no rascunho' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Prepare FROM VALUE #( ( %key-ClienteUUID = lv_cli ) )
      FAILED DATA(ls_failed_prep).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_prep msg = 'Prepare falhou' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Activate FROM VALUE #( ( %cid = 'ACT' %key-ClienteUUID = lv_cli ) )
      FAILED DATA(ls_failed_act).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_act msg = 'Activate falhou' ).

    COMMIT ENTITIES RESPONSE OF zr_pc_cliente FAILED DATA(ls_failed_c) REPORTED DATA(ls_reported_c).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_c msg = 'COMMIT falhou' ).
    cl_abap_unit_assert=>assert_equals( act = contar_enderecos( lv_cli ) exp = 2
                                        msg = 'Cliente deveria ter 2 endereços' ).
  ENDMETHOD.

  METHOD cep_gravado_somente_leitura.
    " CEP faz parte da chave da tabela: alterá-lo num endereço gravado gerava o dump
    " "UPDATE returned unexpected sy-subrc 4". Agora é rejeitado; os demais campos
    " continuam editáveis e gravam normalmente.
    semear( IMPORTING ev_cliente = DATA(lv_cli) ev_endereco = DATA(lv_end) ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Endereco
        UPDATE FIELDS ( Cep )
        WITH VALUE #( ( %tky = VALUE #( EnderecoUUID = lv_end %is_draft = if_abap_behv=>mk-off )
                        Cep = '20040020' ) )
      FAILED DATA(ls_failed_cep).
    cl_abap_unit_assert=>assert_not_initial( act = ls_failed_cep-endereco
                                             msg = 'Alterar o CEP de endereço gravado deve ser rejeitado' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Endereco
        UPDATE FIELDS ( Numero )
        WITH VALUE #( ( %tky = VALUE #( EnderecoUUID = lv_end %is_draft = if_abap_behv=>mk-off )
                        Numero = '99' ) )
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao alterar o número' ).

    COMMIT ENTITIES RESPONSE OF zr_pc_cliente FAILED DATA(ls_failed_c) REPORTED DATA(ls_reported_c).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_c msg = 'COMMIT falhou' ).

    SELECT SINGLE cep, numero FROM zta_pc_endereco WHERE endereco_uuid = @lv_end INTO @DATA(ls_banco).
    cl_abap_unit_assert=>assert_equals( act = ls_banco-numero exp = '99' msg = 'Número deveria ter sido gravado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_banco-cep exp = '01310100' msg = 'CEP não pode mudar' ).
  ENDMETHOD.

  METHOD semear_dois_enderecos.
    " Cliente com dois endereços já gravados: end1 (principal, 01310100) e end2 (20040020)
    semear( IMPORTING ev_cliente = ev_cliente ev_endereco = ev_end1 ).
    ev_end2 = cl_system_uuid=>create_uuid_x16_static( ).
    DATA lt_end TYPE STANDARD TABLE OF zta_pc_endereco WITH EMPTY KEY.
    lt_end = VALUE #( ( client = sy-mandt endereco_uuid = ev_end2 cep = '20040020' cliente_uuid = ev_cliente
                        logradouro = 'Rua da Assembleia' numero = '2' bairro = 'Centro'
                        cidade = 'Rio de Janeiro' uf = 'RJ' estado = 'Rio de Janeiro'
                        cep_status = 'V' endereco_principal = abap_false ) ).
    go_cds->insert_test_data( lt_end ).
  ENDMETHOD.

  METHOD principal_endereco_ativo.
    " Definir endereço principal numa instância ativa: UPDATE de EnderecoPrincipal
    " nos dois endereços já gravados (o novo vira principal, o antigo deixa de ser).
    semear_dois_enderecos( IMPORTING ev_end1 = DATA(lv_end1) ev_end2 = DATA(lv_end2) ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Endereco
        EXECUTE DefinirEnderecoPrincipal
        FROM VALUE #( ( %tky = VALUE #( EnderecoUUID = lv_end2 %is_draft = if_abap_behv=>mk-off ) ) )
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'DefinirEnderecoPrincipal falhou' ).

    COMMIT ENTITIES RESPONSE OF zr_pc_cliente FAILED DATA(ls_failed_c) REPORTED DATA(ls_reported_c).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_c msg = 'COMMIT falhou' ).

    SELECT SINGLE endereco_principal FROM zta_pc_endereco WHERE endereco_uuid = @lv_end1 INTO @DATA(lv_p1).
    SELECT SINGLE endereco_principal FROM zta_pc_endereco WHERE endereco_uuid = @lv_end2 INTO @DATA(lv_p2).
    cl_abap_unit_assert=>assert_equals( act = lv_p2 exp = abap_true  msg = 'Endereço 2 deveria ser o principal' ).
    cl_abap_unit_assert=>assert_equals( act = lv_p1 exp = abap_false msg = 'Endereço 1 deveria deixar de ser principal' ).
  ENDMETHOD.

  METHOD principal_endereco_rascunho.
    " Editar o cliente, definir o outro endereço como principal no rascunho e salvar.
    semear_dois_enderecos( IMPORTING ev_cliente = DATA(lv_cli) ev_end1 = DATA(lv_end1)
                                     ev_end2 = DATA(lv_end2) ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Edit FROM VALUE #( ( %cid = 'ED' %key-ClienteUUID = lv_cli ) )
      FAILED DATA(ls_failed_ed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_ed msg = 'Edit falhou' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Endereco
        EXECUTE DefinirEnderecoPrincipal
        FROM VALUE #( ( %tky = VALUE #( EnderecoUUID = lv_end2 %is_draft = if_abap_behv=>mk-on ) ) )
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'DefinirEnderecoPrincipal no rascunho falhou' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Prepare FROM VALUE #( ( %key-ClienteUUID = lv_cli ) )
      FAILED DATA(ls_failed_prep).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_prep msg = 'Prepare falhou' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Activate FROM VALUE #( ( %cid = 'ACT' %key-ClienteUUID = lv_cli ) )
      FAILED DATA(ls_failed_act).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_act msg = 'Activate falhou' ).

    COMMIT ENTITIES RESPONSE OF zr_pc_cliente FAILED DATA(ls_failed_c) REPORTED DATA(ls_reported_c).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_c msg = 'COMMIT falhou' ).

    SELECT SINGLE endereco_principal FROM zta_pc_endereco WHERE endereco_uuid = @lv_end1 INTO @DATA(lv_p1).
    SELECT SINGLE endereco_principal FROM zta_pc_endereco WHERE endereco_uuid = @lv_end2 INTO @DATA(lv_p2).
    cl_abap_unit_assert=>assert_equals( act = lv_p2 exp = abap_true  msg = 'Endereço 2 deveria ser o principal' ).
    cl_abap_unit_assert=>assert_equals( act = lv_p1 exp = abap_false msg = 'Endereço 1 deveria deixar de ser principal' ).
  ENDMETHOD.

  METHOD numero_endereco_rascunho.
    " Editar o cliente, alterar o número de um endereço já gravado no rascunho e salvar.
    semear_dois_enderecos( IMPORTING ev_cliente = DATA(lv_cli) ev_end2 = DATA(lv_end2) ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Edit FROM VALUE #( ( %cid = 'ED' %key-ClienteUUID = lv_cli ) )
      FAILED DATA(ls_failed_ed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_ed msg = 'Edit falhou' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Endereco
        UPDATE FIELDS ( Numero )
        WITH VALUE #( ( %tky = VALUE #( EnderecoUUID = lv_end2 %is_draft = if_abap_behv=>mk-on )
                        Numero = '77' ) )
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao alterar o número no rascunho' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Prepare FROM VALUE #( ( %key-ClienteUUID = lv_cli ) )
      FAILED DATA(ls_failed_prep).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_prep msg = 'Prepare falhou' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Activate FROM VALUE #( ( %cid = 'ACT' %key-ClienteUUID = lv_cli ) )
      FAILED DATA(ls_failed_act).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_act msg = 'Activate falhou' ).

    COMMIT ENTITIES RESPONSE OF zr_pc_cliente FAILED DATA(ls_failed_c) REPORTED DATA(ls_reported_c).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_c msg = 'COMMIT falhou' ).

    SELECT SINGLE numero FROM zta_pc_endereco WHERE endereco_uuid = @lv_end2 INTO @DATA(lv_numero).
    cl_abap_unit_assert=>assert_equals( act = lv_numero exp = '77' msg = 'Número deveria ter sido gravado' ).
  ENDMETHOD.

ENDCLASS.


*"* SKU do item: gerado no Save (Prepare) com as 3 primeiras letras da categoria
*"* e número sequencial do intervalo 02 de ZPC_NR (rode ZCL_PC_SETUP antes).
CLASS ltcl_sku_item DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS sku_usa_prefixo_categoria FOR TESTING.
    METHODS sku_sequencial_distinto FOR TESTING.
    METHODS criar_item
      IMPORTING iv_categoria   TYPE csequence
      RETURNING VALUE(rv_sku)  TYPE zta_pc_item-sku.
ENDCLASS.


CLASS ltcl_sku_item IMPLEMENTATION.

  METHOD criar_item.
    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        CREATE FIELDS ( Nome Categoria QtdeEstoque PrecoUnitario Currency )
        WITH VALUE #( ( %cid = 'IT1' %is_draft = if_abap_behv=>mk-on
                        Nome = 'Item QA SKU' Categoria = iv_categoria QtdeEstoque = 10
                        PrecoUnitario = '5.00' Currency = 'BRL' ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao criar o rascunho do item' ).
    DATA(lv_uuid) = ls_mapped-item[ 1 ]-ItemUUID.

    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        EXECUTE Prepare FROM VALUE #( ( %key-ItemUUID = lv_uuid ) )
      FAILED DATA(ls_failed_prep).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_prep msg = 'Prepare do item falhou' ).

    READ ENTITIES OF zr_pc_item
      ENTITY Item
        FIELDS ( Sku )
        WITH VALUE #( ( ItemUUID = lv_uuid %is_draft = if_abap_behv=>mk-on ) )
      RESULT DATA(lt_item).
    rv_sku = lt_item[ 1 ]-Sku.
  ENDMETHOD.

  METHOD sku_usa_prefixo_categoria.
    DATA(lv_sku) = criar_item( 'ELETRONICOS' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_sku CP 'SKU-ELE-*' )
                                      msg = |SKU deveria começar com SKU-ELE-: { lv_sku }| ).
  ENDMETHOD.

  METHOD sku_sequencial_distinto.
    DATA(lv_sku1) = criar_item( 'INFORMATICA' ).
    DATA(lv_sku2) = criar_item( 'INFORMATICA' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_sku1 CP 'SKU-INF-*' )
                                      msg = |SKU deveria começar com SKU-INF-: { lv_sku1 }| ).
    cl_abap_unit_assert=>assert_differs( act = lv_sku2 exp = lv_sku1 msg = 'SKUs devem ser únicos' ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_estoque_endereco DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS status_sem_estoque        FOR TESTING.
    METHODS status_negativo           FOR TESTING.
    METHODS status_acabando_limite_1  FOR TESTING.
    METHODS status_acabando_limite_10 FOR TESTING.
    METHODS status_em_estoque         FOR TESTING.
    METHODS endereco_com_complemento  FOR TESTING.
    METHODS endereco_sem_complemento  FOR TESTING.
ENDCLASS.


CLASS ltcl_estoque_endereco IMPLEMENTATION.

  METHOD status_sem_estoque.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>calcular_status_estoque( 0 )
      exp = zif_pc_constants=>c_status_estoque-sem_estoque
      msg = 'Disponível 0 => SEM_ESTOQUE' ).
  ENDMETHOD.

  METHOD status_negativo.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>calcular_status_estoque( -5 )
      exp = zif_pc_constants=>c_status_estoque-sem_estoque
      msg = 'Disponível negativo nunca deve indicar estoque' ).
  ENDMETHOD.

  METHOD status_acabando_limite_1.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>calcular_status_estoque( 1 )
      exp = zif_pc_constants=>c_status_estoque-acabando
      msg = 'Disponível 1 => ACABANDO (limite inferior)' ).
  ENDMETHOD.

  METHOD status_acabando_limite_10.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>calcular_status_estoque( 10 )
      exp = zif_pc_constants=>c_status_estoque-acabando
      msg = 'Disponível 10 => ACABANDO (limite superior)' ).
  ENDMETHOD.

  METHOD status_em_estoque.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>calcular_status_estoque( 11 )
      exp = zif_pc_constants=>c_status_estoque-em_estoque
      msg = 'Disponível 11 => EM_ESTOQUE' ).
  ENDMETHOD.

  METHOD endereco_com_complemento.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>formatar_endereco( iv_logradouro  = 'Praça da Sé'
                                            iv_numero      = '100'
                                            iv_complemento = 'Sala 1'
                                            iv_bairro      = 'Sé'
                                            iv_cidade      = 'São Paulo'
                                            iv_uf          = 'SP'
                                            iv_cep         = '01001000' )
      exp = `Praça da Sé, 100 - Sala 1 - Sé - São Paulo/SP - CEP 01001-000`
      msg = 'Endereço completo com complemento' ).
  ENDMETHOD.

  METHOD endereco_sem_complemento.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_util=>formatar_endereco( iv_logradouro = 'Avenida Paulista'
                                            iv_numero     = '1000'
                                            iv_bairro     = 'Bela Vista'
                                            iv_cidade     = 'São Paulo'
                                            iv_uf         = 'SP'
                                            iv_cep        = '01310100' )
      exp = `Avenida Paulista, 1000 - Bela Vista - São Paulo/SP - CEP 01310-100`
      msg = 'Sem complemento o separador extra não deve aparecer' ).
  ENDMETHOD.

ENDCLASS.