"! <p class="shorttext synchronized">Pedidos de Compras - Carga de clientes de demonstração</p>
"! Insere 100 clientes (cada um com um endereço principal já validado).
"! Pode ser executada mais de uma vez: CPFs já existentes são ignorados.
CLASS zcl_setup_cliente DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_quantidade TYPE i VALUE 100.

    METHODS carregar_dados
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out
      RAISING   cx_uuid_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_nome,
        nome   TYPE string,
        genero TYPE zta_pc_cliente-genero,
      END OF ty_nome.
    TYPES:
      BEGIN OF ty_cep,
        cep        TYPE zta_pc_endereco-cep,
        logradouro TYPE zta_pc_endereco-logradouro,
        bairro     TYPE zta_pc_endereco-bairro,
        cidade     TYPE zta_pc_endereco-cidade,
        uf         TYPE zta_pc_endereco-uf,
        estado     TYPE zta_pc_endereco-estado,
      END OF ty_cep.
ENDCLASS.



CLASS zcl_setup_cliente IMPLEMENTATION.

  METHOD carregar_dados.
    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    DATA(lv_usuario) = CONV abp_creation_user( 'SETUP' ).
    TRY.
        lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        " mantém 'SETUP'
    ENDTRY.

    DATA lt_nomes TYPE STANDARD TABLE OF ty_nome WITH EMPTY KEY.
    DATA lt_ceps  TYPE STANDARD TABLE OF ty_cep WITH EMPTY KEY.

    lt_nomes = VALUE #(
      ( nome = `Maria`     genero = 'FEMININO' )
      ( nome = `João`      genero = 'MASCULINO' )
      ( nome = `Ana`       genero = 'FEMININO' )
      ( nome = `Carlos`    genero = 'MASCULINO' )
      ( nome = `Juliana`   genero = 'FEMININO' )
      ( nome = `Pedro`     genero = 'MASCULINO' )
      ( nome = `Fernanda`  genero = 'FEMININO' )
      ( nome = `Lucas`     genero = 'MASCULINO' )
      ( nome = `Camila`    genero = 'FEMININO' )
      ( nome = `Rafael`    genero = 'MASCULINO' )
      ( nome = `Patrícia`  genero = 'FEMININO' )
      ( nome = `Marcelo`   genero = 'MASCULINO' )
      ( nome = `Luciana`   genero = 'FEMININO' )
      ( nome = `Bruno`     genero = 'MASCULINO' )
      ( nome = `Beatriz`   genero = 'FEMININO' )
      ( nome = `Felipe`    genero = 'MASCULINO' )
      ( nome = `Aline`     genero = 'FEMININO' )
      ( nome = `Gustavo`   genero = 'MASCULINO' )
      ( nome = `Renata`    genero = 'FEMININO' )
      ( nome = `Eduardo`   genero = 'MASCULINO' ) ).

    DATA(lt_sobrenomes) = VALUE string_table(
      ( `Silva` ) ( `Souza` ) ( `Oliveira` ) ( `Santos` ) ( `Pereira` )
      ( `Costa` ) ( `Rodrigues` ) ( `Almeida` ) ( `Nascimento` ) ( `Lima` )
      ( `Araújo` ) ( `Fernandes` ) ( `Carvalho` ) ( `Gomes` ) ( `Martins` )
      ( `Rocha` ) ( `Ribeiro` ) ( `Barbosa` ) ( `Moreira` ) ( `Cardoso` ) ).

    lt_ceps = VALUE #(
      ( cep = '01001000' logradouro = 'Praça da Sé'                   bairro = 'Sé'               cidade = 'São Paulo'      uf = 'SP' estado = 'São Paulo' )
      ( cep = '01310100' logradouro = 'Avenida Paulista'              bairro = 'Bela Vista'       cidade = 'São Paulo'      uf = 'SP' estado = 'São Paulo' )
      ( cep = '04538133' logradouro = 'Avenida Brigadeiro Faria Lima' bairro = 'Itaim Bibi'       cidade = 'São Paulo'      uf = 'SP' estado = 'São Paulo' )
      ( cep = '20011000' logradouro = 'Rua da Assembleia'             bairro = 'Centro'           cidade = 'Rio de Janeiro' uf = 'RJ' estado = 'Rio de Janeiro' )
      ( cep = '22021001' logradouro = 'Avenida Atlântica'             bairro = 'Copacabana'       cidade = 'Rio de Janeiro' uf = 'RJ' estado = 'Rio de Janeiro' )
      ( cep = '30130003' logradouro = 'Avenida Afonso Pena'           bairro = 'Centro'           cidade = 'Belo Horizonte' uf = 'MG' estado = 'Minas Gerais' )
      ( cep = '40020000' logradouro = 'Rua Chile'                     bairro = 'Centro'           cidade = 'Salvador'       uf = 'BA' estado = 'Bahia' )
      ( cep = '50060004' logradouro = 'Avenida Conde da Boa Vista'    bairro = 'Boa Vista'        cidade = 'Recife'         uf = 'PE' estado = 'Pernambuco' )
      ( cep = '60165121' logradouro = 'Avenida Beira Mar'             bairro = 'Meireles'         cidade = 'Fortaleza'      uf = 'CE' estado = 'Ceará' )
      ( cep = '80020310' logradouro = 'Rua XV de Novembro'            bairro = 'Centro'           cidade = 'Curitiba'       uf = 'PR' estado = 'Paraná' )
      ( cep = '90020007' logradouro = 'Rua dos Andradas'              bairro = 'Centro Histórico' cidade = 'Porto Alegre'   uf = 'RS' estado = 'Rio Grande do Sul' ) ).

    SELECT cpf FROM zta_pc_cliente INTO TABLE @DATA(lt_cpf_existentes).

    DATA lt_clientes  TYPE STANDARD TABLE OF zta_pc_cliente WITH EMPTY KEY.
    DATA lt_enderecos TYPE STANDARD TABLE OF zta_pc_endereco WITH EMPTY KEY.

    DO c_quantidade TIMES.
      DATA(lv_i) = sy-index.

      " CPF válido e determinístico: base de 9 dígitos + dígitos verificadores
      DATA(lv_cpf) = zcl_pc_util=>calcular_dv_cpf( |{ 100000000 + lv_i * 3571 }| ).
      IF line_exists( lt_cpf_existentes[ cpf = lv_cpf ] ).
        CONTINUE.
      ENDIF.

      DATA(ls_nome)       = lt_nomes[ ( lv_i - 1 ) MOD lines( lt_nomes ) + 1 ].
      DATA(lv_sobrenome1) = lt_sobrenomes[ lv_i MOD lines( lt_sobrenomes ) + 1 ].
      DATA(lv_sobrenome2) = lt_sobrenomes[ ( lv_i * 7 + 3 ) MOD lines( lt_sobrenomes ) + 1 ].
      DATA(lv_nome)       = |{ ls_nome-nome } { lv_sobrenome1 } { lv_sobrenome2 }|.

      " e-mail sem acentos/espaços e único por índice
      DATA(lv_email) = translate( val  = to_lower( lv_nome )
                                  from = 'áàâãäéèêëíìîïóòôõöúùûüç '
                                  to   = 'aaaaaeeeeiiiiooooouuuuc.' ).
      lv_email = |{ lv_email }.{ lv_i }@example.com|.

      DATA(lv_genero) = COND zta_pc_cliente-genero(
        WHEN lv_i MOD 17 = 0 THEN 'NAO_INFORMADO'
        ELSE ls_nome-genero ).

      DATA(lv_nascimento) = CONV d( |{ 1960 + lv_i MOD 44 }| &&
                                    |{ 1 + lv_i MOD 12 WIDTH = 2 ALIGN = RIGHT PAD = '0' }| &&
                                    |{ 1 + lv_i MOD 28 WIDTH = 2 ALIGN = RIGHT PAD = '0' }| ).

      DATA(lv_cliente_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

      APPEND VALUE #(
        cliente_uuid          = lv_cliente_uuid
        cpf                   = lv_cpf
        nome                  = lv_nome
        email                 = lv_email
        telefone              = |{ 11 + lv_i MOD 20 }9{ 20000000 + lv_i * 123457 }|
        genero                = lv_genero
        data_nascimento       = lv_nascimento
        cliente_ativo         = xsdbool( lv_i MOD 15 <> 0 )
        score_cliente         = 30 + ( lv_i * 37 ) MOD 70
        created_by            = lv_usuario
        created_at            = lv_agora
        last_changed_by       = lv_usuario
        last_changed_at       = lv_agora
        local_last_changed_at = lv_agora ) TO lt_clientes.

      DATA(ls_cep) = lt_ceps[ ( lv_i - 1 ) MOD lines( lt_ceps ) + 1 ].
      APPEND VALUE #(
        endereco_uuid         = cl_system_uuid=>create_uuid_x16_static( )
        cliente_uuid          = lv_cliente_uuid
        cep                   = ls_cep-cep
        logradouro            = ls_cep-logradouro
        numero                = |{ 10 + ( lv_i * 37 ) MOD 990 }|
        complemento           = COND #( WHEN lv_i MOD 3 = 0 THEN |Apto { 101 + lv_i MOD 400 }| ELSE `` )
        bairro                = ls_cep-bairro
        cidade                = ls_cep-cidade
        uf                    = ls_cep-uf
        estado                = ls_cep-estado
        endereco_principal    = abap_true
        cep_status            = zif_pc_constants=>c_status_cep-validado
        created_by            = lv_usuario
        created_at            = lv_agora
        last_changed_by       = lv_usuario
        last_changed_at       = lv_agora
        local_last_changed_at = lv_agora ) TO lt_enderecos.
    ENDDO.

    IF lt_clientes IS INITIAL.
      io_out->write( `Clientes de demonstração já carregados: nada a inserir.` ).
      RETURN.
    ENDIF.

    INSERT zta_pc_cliente FROM TABLE @lt_clientes.
    INSERT zta_pc_endereco FROM TABLE @lt_enderecos.

    io_out->write( |Clientes de demonstração criados: { lines( lt_clientes ) } (com endereço principal).| ).
  ENDMETHOD.

ENDCLASS.
