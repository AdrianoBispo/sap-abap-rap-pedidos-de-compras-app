"! <p class="shorttext synchronized">Pedidos de Compras - Setup (numeração, CodeLists e dados demo)</p>
"! Executar no ADT com F9 (Run as ABAP Application - Console) DEPOIS de
"! ativar todos os objetos. Pode ser executada mais de uma vez.
"!  1. Cria os intervalos 01 (pedido) e 02 (SKU) do objeto ZPC_NR
"!  2. Recarrega a tabela ZTA_PC_CODELIST
"!  3. Insere dados de demonstração se as tabelas estiverem vazias
"!  4. Marca como consultados os endereços gravados antes de ConsultedCep
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
    METHODS carregar_dados_demo
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out
      RAISING   cx_uuid_error cx_number_ranges.
    METHODS migrar_enderecos_cep
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.



CLASS zcl_pc_setup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    criar_intervalos( out ).
    carregar_codelists( out ).
    TRY.
        carregar_dados_demo( out ).
      CATCH cx_uuid_error cx_number_ranges INTO DATA(lx).
        out->write( |Erro nos dados demo: { lx->get_text( ) }| ).
    ENDTRY.
    migrar_enderecos_cep( out ).
    COMMIT WORK.
    out->write( `Setup concluído.` ).
  ENDMETHOD.


  METHOD criar_intervalos.
    DATA lt_intervalos TYPE cl_numberrange_intervals=>nr_interval.

    lt_intervalos = VALUE #(
      ( nrrangenr  = zif_pc_constants=>c_numeracao-intervalo_pedido
        fromnumber = '0000000001'
        tonumber   = '9999999999'
        procind    = 'I' )
      ( nrrangenr  = zif_pc_constants=>c_numeracao-intervalo_sku
        fromnumber = '0000000001'
        tonumber   = '9999999999'
        procind    = 'I' ) ).

    TRY.
        cl_numberrange_intervals=>create(
          EXPORTING
            interval  = lt_intervalos
            object    = CONV #( zif_pc_constants=>c_numeracao-objeto )
            subobject = ' '
          IMPORTING
            error     = DATA(lv_erro)
            error_inf = DATA(ls_erro_inf)
            error_iv  = DATA(lt_erro_iv)
            warning   = DATA(lv_aviso) ).

        IF lv_erro = abap_true.
          io_out->write( `Intervalos de numeração já existem ou não puderam ser criados (verifique ZPC_NR).` ).
        ELSE.
          io_out->write( `Intervalos de numeração 01 (pedido) e 02 (SKU) criados.` ).
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        io_out->write( |Numeração: { lx->get_text( ) }| ).
    ENDTRY.
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
      ( lista = 'STATUS_PEDIDO' codigo = 'CRIADO'               descricao = 'Criado'                criticality = 0 ordem = 1 )
      ( lista = 'STATUS_PEDIDO' codigo = 'AGUARDANDO_PAGAMENTO' descricao = 'Aguardando pagamento'  criticality = 2 ordem = 2 )
      ( lista = 'STATUS_PEDIDO' codigo = 'AGUARDANDO_APROVACAO' descricao = 'Aguardando aprovação'  criticality = 2 ordem = 3 )
      ( lista = 'STATUS_PEDIDO' codigo = 'FINALIZADO'           descricao = 'Finalizado'            criticality = 3 ordem = 4 )
      ( lista = 'STATUS_PEDIDO' codigo = 'CANCELADO'            descricao = 'Cancelado'             criticality = 1 ordem = 5 )
      " Status do pagamento
      ( lista = 'STATUS_PAGAMENTO' codigo = 'PENDENTE' descricao = 'Pendente' criticality = 2 ordem = 1 )
      ( lista = 'STATUS_PAGAMENTO' codigo = 'APROVADO' descricao = 'Aprovado' criticality = 3 ordem = 2 )
      ( lista = 'STATUS_PAGAMENTO' codigo = 'RECUSADO' descricao = 'Recusado' criticality = 1 ordem = 3 )
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


  METHOD carregar_dados_demo.
    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    DATA(lv_usuario) = CONV abp_creation_user( 'SETUP' ).
    TRY.
        lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        " mantém 'SETUP'
    ENDTRY.

    " ---------------------------------------------------------------- Clientes
    SELECT COUNT( * ) FROM zta_pc_cliente INTO @DATA(lv_qtd_clientes).
    IF lv_qtd_clientes = 0.
      DATA(lv_cli1) = cl_system_uuid=>create_uuid_x16_static( ).
      DATA(lv_cli2) = cl_system_uuid=>create_uuid_x16_static( ).

      DATA lt_clientes TYPE STANDARD TABLE OF zta_pc_cliente WITH EMPTY KEY.
      lt_clientes = VALUE #(
        ( cliente_uuid = lv_cli1 cpf = zcl_pc_util=>calcular_dv_cpf( '529982247' )
          nome = 'Maria Aparecida Souza' email = 'maria.souza@example.com' telefone = '11987654321'
          genero = 'FEMININO' data_nascimento = '19900415' cliente_ativo = abap_true score_cliente = '87.50'
          created_by = lv_usuario created_at = lv_agora last_changed_by = lv_usuario
          last_changed_at = lv_agora local_last_changed_at = lv_agora )
        ( cliente_uuid = lv_cli2 cpf = zcl_pc_util=>calcular_dv_cpf( '390533447' )
          nome = 'João Carlos Pereira' email = 'joao.pereira@example.com' telefone = '11912345678'
          genero = 'MASCULINO' data_nascimento = '19851120' cliente_ativo = abap_true score_cliente = '72.00'
          created_by = lv_usuario created_at = lv_agora last_changed_by = lv_usuario
          last_changed_at = lv_agora local_last_changed_at = lv_agora ) ).
      INSERT zta_pc_cliente FROM TABLE @lt_clientes.

      DATA lt_enderecos TYPE STANDARD TABLE OF zta_pc_endereco WITH EMPTY KEY.
      lt_enderecos = VALUE #(
        ( endereco_uuid = cl_system_uuid=>create_uuid_x16_static( ) cliente_uuid = lv_cli1
          cep = '01001000' logradouro = 'Praça da Sé' numero = '100' complemento = 'Sala 1'
          bairro = 'Sé' cidade = 'São Paulo' uf = 'SP' estado = 'São Paulo' endereco_principal = abap_true
          cep_status = zif_pc_constants=>c_status_cep-validado consulted_cep = '01001000'
          created_by = lv_usuario created_at = lv_agora last_changed_by = lv_usuario
          last_changed_at = lv_agora local_last_changed_at = lv_agora )
        ( endereco_uuid = cl_system_uuid=>create_uuid_x16_static( ) cliente_uuid = lv_cli2
          cep = '01310100' logradouro = 'Avenida Paulista' numero = '1000'
          bairro = 'Bela Vista' cidade = 'São Paulo' uf = 'SP' estado = 'São Paulo' endereco_principal = abap_true
          cep_status = zif_pc_constants=>c_status_cep-validado consulted_cep = '01310100'
          created_by = lv_usuario created_at = lv_agora last_changed_by = lv_usuario
          last_changed_at = lv_agora local_last_changed_at = lv_agora ) ).
      INSERT zta_pc_endereco FROM TABLE @lt_enderecos.

      io_out->write( `Clientes e endereços de demonstração criados.` ).
    ENDIF.

    " ------------------------------------------------------------------ Itens
    SELECT COUNT( * ) FROM zta_pc_item INTO @DATA(lv_qtd_itens).
    IF lv_qtd_itens = 0.
      TYPES:
        BEGIN OF ty_demo,
          nome      TYPE zta_pc_item-nome,
          descricao TYPE zta_pc_item-descricao,
          categoria TYPE zta_pc_item-categoria,
          estoque   TYPE i,
          preco     TYPE zta_pc_item-preco_unitario,
        END OF ty_demo.
      DATA lt_demo TYPE STANDARD TABLE OF ty_demo WITH EMPTY KEY.
      DATA lt_itens TYPE STANDARD TABLE OF zta_pc_item WITH EMPTY KEY.

      lt_demo = VALUE #(
        ( nome = 'Notebook 14 polegadas' descricao = 'Notebook para uso educacional' categoria = 'INFORMATICA' estoque = 25 preco = '3499.90' )
        ( nome = 'Mouse sem fio'         descricao = 'Mouse óptico sem fio'           categoria = 'INFORMATICA' estoque = 8  preco = '89.90' )
        ( nome = 'Fone Bluetooth'        descricao = 'Fone de ouvido Bluetooth'       categoria = 'ELETRONICOS' estoque = 0  preco = '199.00' )
        ( nome = 'Cadeira de escritório' descricao = 'Cadeira ergonômica'             categoria = 'ESCRITORIO'  estoque = 12 preco = '899.00' ) ).

      LOOP AT lt_demo INTO DATA(ls_demo).
        APPEND VALUE #( item_uuid       = cl_system_uuid=>create_uuid_x16_static( )
                        sku             = zcl_pc_numeracao=>gerar_sku( ls_demo-categoria )
                        nome            = ls_demo-nome
                        descricao       = ls_demo-descricao
                        categoria       = ls_demo-categoria
                        qtde_estoque    = ls_demo-estoque
                        qtde_reservada  = 0
                        qtde_disponivel = ls_demo-estoque
                        status_estoque  = zcl_pc_util=>calcular_status_estoque( ls_demo-estoque )
                        currency        = zif_pc_constants=>c_moeda_padrao
                        preco_unitario  = ls_demo-preco
                        item_ativo      = abap_true
                        created_by      = lv_usuario created_at = lv_agora
                        last_changed_by = lv_usuario last_changed_at = lv_agora
                        local_last_changed_at = lv_agora ) TO lt_itens.
      ENDLOOP.
      INSERT zta_pc_item FROM TABLE @lt_itens.

      io_out->write( `Itens de estoque de demonstração criados.` ).
    ENDIF.
  ENDMETHOD.


  METHOD migrar_enderecos_cep.
    " ValidarCep exige ConsultedCep = Cep. Endereços gravados antes desse campo
    " (determination antiga com CepStatus V, ou dados demo sem status) já foram
    " validados no ViaCEP: registra o CEP deles como consultado.
    UPDATE zta_pc_endereco
      SET consulted_cep = cep,
          cep_status    = @zif_pc_constants=>c_status_cep-validado
      WHERE consulted_cep = @space
        AND cidade        <> @space
        AND ( cep_status = @zif_pc_constants=>c_status_cep-validado OR cep_status = @space ).
    io_out->write( |Endereços migrados para ConsultedCep: { sy-dbcnt }| ).
  ENDMETHOD.

ENDCLASS.
