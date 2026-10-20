"! <p class="shorttext synchronized">Pedidos de Compras - Setup (numeração, CodeLists e dados demo)</p>
"! Executar no ADT com F9 (Run as ABAP Application - Console) DEPOIS de
"! ativar todos os objetos. Pode ser executada mais de uma vez.
"!  1. Cria os intervalos 01 (pedido) e 02 (SKU) do objeto ZPC_NR
"!  2. Recarrega a tabela ZTA_PC_CODELIST
"!  3. Carrega os dados de demonstração, cada um em sua classe:
"!     ZCL_SETUP_CLIENTE (100 clientes), ZCL_SETUP_ESTOQUE (100 itens) e
"!     ZCL_SETUP_PEDIDOS (100 pedidos, 10 deles com reembolso pendente)
"!  4. Marca como validados (CepStatus V) os endereços gravados antes do CepStatus
"!  5. Migra pedidos do modelo antigo de status (CRIADO, AGUARDANDO_PAGAMENTO,
"!     PROCESSAR_REEMBOLSO) para o atual (ABERTO, PROCESSANDO_REEMBOLSO)
CLASS zcl_pc_setup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS criar_intervalos
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out.
    METHODS carregar_codelists
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out.
    METHODS migrar_enderecos_cep
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out.
    METHODS migrar_status_pedidos
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.

CLASS zcl_pc_setup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    criar_intervalos( out ).
    carregar_codelists( out ).
    " Ordem importa: pedidos dependem de clientes e itens já gravados
    TRY.
        NEW zcl_setup_cliente( )->carregar_dados( out ).
        NEW zcl_setup_estoque( )->carregar_dados( out ).
        NEW zcl_setup_pedidos( )->carregar_dados( out ).
      CATCH cx_uuid_error cx_number_ranges INTO DATA(lx).
        out->write( |Erro nos dados demo: { lx->get_text( ) }| ).
    ENDTRY.
    migrar_enderecos_cep( out ).
    migrar_status_pedidos( out ).
    COMMIT WORK.
    out->write( `Setup concluído.` ).
  ENDMETHOD.


  METHOD criar_intervalos.
    " Um intervalo por chamada: se um já existir, o outro ainda é criado.
    " Os intervalos não podem se sobrepor dentro do mesmo objeto.
    DATA lt_intervalos TYPE cl_numberrange_intervals=>nr_interval.
    DATA lt_um         TYPE cl_numberrange_intervals=>nr_interval.

    lt_intervalos = VALUE #(
      ( nrrangenr  = zif_pc_constants=>c_numeracao-intervalo_pedido
        fromnumber = zif_pc_constants=>c_numeracao-pedido_de
        tonumber   = zif_pc_constants=>c_numeracao-pedido_ate
        procind    = 'I' )
      ( nrrangenr  = zif_pc_constants=>c_numeracao-intervalo_sku
        fromnumber = zif_pc_constants=>c_numeracao-sku_de
        tonumber   = zif_pc_constants=>c_numeracao-sku_ate
        procind    = 'I' ) ).

    LOOP AT lt_intervalos INTO DATA(ls_intervalo).
      lt_um = VALUE #( ( ls_intervalo ) ).
      TRY.
          cl_numberrange_intervals=>create(
            EXPORTING
              interval  = lt_um
              object    = CONV #( zif_pc_constants=>c_numeracao-objeto )
              subobject = ' '
            IMPORTING
              error     = DATA(lv_erro) ).

          io_out->write( COND string(
            WHEN lv_erro = abap_true
            THEN |Intervalo { ls_intervalo-nrrangenr }: já existe ou não pôde ser criado (verifique ZPC_NR).|
            ELSE |Intervalo { ls_intervalo-nrrangenr } criado ({ ls_intervalo-fromnumber } a { ls_intervalo-tonumber }).| ) ).
        CATCH cx_number_ranges INTO DATA(lx).
          io_out->write( |Intervalo { ls_intervalo-nrrangenr }: { lx->get_text( ) }| ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD carregar_codelists.
    DATA lt_codelist TYPE STANDARD TABLE OF zta_pc_codelist WITH EMPTY KEY.

    lt_codelist = VALUE #(
      " Gênero
      ( lista = 'GENERO' codigo = 'MASCULINO'      descricao = 'Masculino'             ordem = 1 )
      ( lista = 'GENERO' codigo = 'FEMININO'       descricao = 'Feminino'              ordem = 2 )
      ( lista = 'GENERO' codigo = 'NAO_BINARIO'    descricao = 'Não binário'           ordem = 3 )
      ( lista = 'GENERO' codigo = 'OUTRO'          descricao = 'Outro'                 ordem = 4 )
      ( lista = 'GENERO' codigo = 'NAO_INFORMADO'  descricao = 'Prefiro não informar'  ordem = 5 )
      " Categoria (as 3 primeiras letras compõem o SKU)
      ( lista = 'CATEGORIA' codigo = 'ELETRONICOS' descricao = 'Eletrônicos'           ordem = 1 )
      ( lista = 'CATEGORIA' codigo = 'INFORMATICA' descricao = 'Informática'           ordem = 2 )
      ( lista = 'CATEGORIA' codigo = 'ESCRITORIO'  descricao = 'Escritório'            ordem = 3 )
      ( lista = 'CATEGORIA' codigo = 'CASA'        descricao = 'Casa e decoração'      ordem = 4 )
      ( lista = 'CATEGORIA' codigo = 'VESTUARIO'   descricao = 'Vestuário'             ordem = 5 )
      ( lista = 'CATEGORIA' codigo = 'ALIMENTOS'   descricao = 'Alimentos'             ordem = 6 )
      ( lista = 'CATEGORIA' codigo = 'OUTROS'      descricao = 'Outros'                ordem = 7 )
      " Status do pedido (criticality: 0 neutro, 1 vermelho, 2 amarelo, 3 verde)
      ( lista = 'STATUS_PEDIDO' codigo = 'ABERTO'                descricao = 'Aberto'                criticality = 0 ordem = 1 )
      ( lista = 'STATUS_PEDIDO' codigo = 'AGUARDANDO_APROVACAO'  descricao = 'Aguardando aprovação'  criticality = 2 ordem = 2 )
      ( lista = 'STATUS_PEDIDO' codigo = 'PROCESSANDO_REEMBOLSO' descricao = 'Processando reembolso' criticality = 2 ordem = 3 )
      ( lista = 'STATUS_PEDIDO' codigo = 'CANCELADO'             descricao = 'Cancelado'             criticality = 1 ordem = 4 )
      ( lista = 'STATUS_PEDIDO' codigo = 'FINALIZADO'            descricao = 'Finalizado'            criticality = 3 ordem = 5 )
      " Status do pagamento
      ( lista = 'STATUS_PAGAMENTO' codigo = 'PENDENTE'  descricao = 'Pendente'  criticality = 2 ordem = 1 )
      ( lista = 'STATUS_PAGAMENTO' codigo = 'APROVADO'  descricao = 'Aprovado'  criticality = 3 ordem = 2 )
      ( lista = 'STATUS_PAGAMENTO' codigo = 'RECUSADO'  descricao = 'Recusado'  criticality = 1 ordem = 3 )
      ( lista = 'STATUS_PAGAMENTO' codigo = 'DEVOLVIDO' descricao = 'Devolvido' criticality = 0 ordem = 4 )
      " Status do reembolso
      ( lista = 'STATUS_REEMBOLSO' codigo = 'PENDENTE'  descricao = 'Pendente'  criticality = 2 ordem = 1 )
      ( lista = 'STATUS_REEMBOLSO' codigo = 'APROVADO'  descricao = 'Aprovado'  criticality = 3 ordem = 2 )
      ( lista = 'STATUS_REEMBOLSO' codigo = 'REJEITADO' descricao = 'Rejeitado' criticality = 1 ordem = 3 )
      " Status do estoque
      ( lista = 'STATUS_ESTOQUE' codigo = 'SEM_ESTOQUE' descricao = 'Sem estoque' criticality = 1 ordem = 1 )
      ( lista = 'STATUS_ESTOQUE' codigo = 'ACABANDO'    descricao = 'Acabando'    criticality = 2 ordem = 2 )
      ( lista = 'STATUS_ESTOQUE' codigo = 'EM_ESTOQUE'  descricao = 'Em estoque'  criticality = 3 ordem = 3 )
      " Método de pagamento
      ( lista = 'METODO_PAGAMENTO' codigo = 'CARTAO_CREDITO' descricao = 'Cartão de crédito' ordem = 1 )
      ( lista = 'METODO_PAGAMENTO' codigo = 'CARTAO_DEBITO'  descricao = 'Cartão de débito'  ordem = 2 ) ).

    DELETE FROM zta_pc_codelist.
    INSERT zta_pc_codelist FROM TABLE @lt_codelist.
    io_out->write( |CodeLists carregadas: { lines( lt_codelist ) } registros.| ).
  ENDMETHOD.


  METHOD migrar_enderecos_cep.
    " ValidarCep exige CepStatus V. Endereços gravados antes desse campo já
    " tinham cidade/UF preenchidas pelo ViaCEP: registra-os como validados.
    UPDATE zta_pc_endereco
      SET cep_status = @zif_pc_constants=>c_status_cep-validado
      WHERE cep_status = @space
        AND cidade     <> @space
        AND uf         <> @space.
    io_out->write( |Endereços marcados como CEP validado: { sy-dbcnt }| ).
  ENDMETHOD.


  METHOD migrar_status_pedidos.
    " Modelo antigo (CRIADO / AGUARDANDO_PAGAMENTO / PROCESSAR_REEMBOLSO) para o
    " novo (ABERTO / PROCESSANDO_REEMBOLSO). Idempotente: sem linhas antigas, nada muda.
    UPDATE zta_pc_pedido SET status_pedido = @zif_pc_constants=>c_status_pedido-aberto
      WHERE status_pedido IN ( 'CRIADO', 'AGUARDANDO_PAGAMENTO' ).
    DATA(lv_abertos) = sy-dbcnt.
    UPDATE zta_pc_pedido SET status_pedido = @zif_pc_constants=>c_status_pedido-processando_reembolso
      WHERE status_pedido = 'PROCESSAR_REEMBOLSO'.
    DATA(lv_reembolso) = sy-dbcnt.
    UPDATE zta_pc_reembolso SET status_pedido_anterior = @zif_pc_constants=>c_status_pedido-aguardando_aprovacao
      WHERE status_pedido_anterior = 'PROCESSAR_REEMBOLSO'.

    " Indicadores usados para exibir/esconder as seções da Object Page
    UPDATE zta_pc_pedido
      SET pedido_encerrado      = @abap_false,
          pedido_ativo_sem_hist = @abap_true,
          pedido_nao_finalizado = @abap_true,
          pedido_nao_cancelado  = @abap_true
      WHERE status_pedido NOT IN ( @zif_pc_constants=>c_status_pedido-finalizado,
                                   @zif_pc_constants=>c_status_pedido-cancelado ).
    UPDATE zta_pc_pedido
      SET pedido_encerrado      = @abap_true,
          pedido_ativo_sem_hist = @abap_false,
          pedido_nao_finalizado = @abap_false,
          pedido_nao_cancelado  = @abap_true
      WHERE status_pedido = @zif_pc_constants=>c_status_pedido-finalizado.
    UPDATE zta_pc_pedido
      SET pedido_encerrado      = @abap_true,
          pedido_ativo_sem_hist = @abap_false,
          pedido_nao_finalizado = @abap_true,
          pedido_nao_cancelado  = @abap_false
      WHERE status_pedido = @zif_pc_constants=>c_status_pedido-cancelado.
    io_out->write( |Pedidos migrados para ABERTO: { lv_abertos }; para PROCESSANDO_REEMBOLSO: { lv_reembolso }.| ).
  ENDMETHOD.

ENDCLASS.