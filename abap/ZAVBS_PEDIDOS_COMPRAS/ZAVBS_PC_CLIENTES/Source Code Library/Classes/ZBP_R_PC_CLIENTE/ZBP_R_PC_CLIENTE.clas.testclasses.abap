*"* Test Classes da behavior pool ZBP_R_PC_CLIENTE (BO Cliente + Endereço)
*"* Testes de integração por EML sobre test doubles: as tabelas do BO
*"* (cl_cds_test_environment) e as de rascunho (cl_osql_test_environment)
*"* começam vazias em cada teste, sem dados reais e sem gravar no banco.
*"* As validations rodam no Prepare do rascunho; nada é confirmado (sem COMMIT).
*"* O ViaCEP não é chamado: os CEPs usados já existem como endereços validados
*"* no double (busca local de PreencherEnderecoViaCep) ou têm formato inválido.
*"* Persistência real de endereços (COMMIT ENTITIES): ZCL_PC_UTIL,
*"* ltcl_persistencia_endereco.

*"* Números T100 (Message Class ZPC_MSG) das mensagens de uma tabela REPORTED.
"! Apoio dos testes: números T100 das mensagens de um REPORTED.
CLASS lcl_msgs DEFINITION FINAL.
  PUBLIC SECTION.
    "! Números T100 (Message Class ZPC_MSG) das mensagens com %msg.
    "! @parameter it_reported | Tabela REPORTED de qualquer entidade
    "! @parameter rt_numeros | Números das mensagens (ex.: 050)
    CLASS-METHODS numeros
      IMPORTING it_reported       TYPE ANY TABLE
      RETURNING VALUE(rt_numeros) TYPE string_table.
ENDCLASS.


CLASS lcl_msgs IMPLEMENTATION.

  METHOD numeros.
    FIELD-SYMBOLS <lo_msg> TYPE REF TO if_abap_behv_message.

    LOOP AT it_reported ASSIGNING FIELD-SYMBOL(<ls_reported>).
      ASSIGN COMPONENT '%MSG' OF STRUCTURE <ls_reported> TO <lo_msg>.
      IF sy-subrc = 0 AND <lo_msg> IS BOUND.
        APPEND CONV string( <lo_msg>->if_t100_message~t100key-msgno ) TO rt_numeros.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


*"* Base: ambiente de test doubles, dados semeados e atalhos de EML.
"! Base dos testes do BO {@link ZR_PC_CLIENTE}: ambiente de test doubles, dados
"! semeados e atalhos de EML usados pelas classes de teste.
CLASS lcl_base_cliente DEFINITION ABSTRACT FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PROTECTED SECTION.
    "! FAILED do BO Cliente
    TYPES ty_failed    TYPE RESPONSE FOR FAILED EARLY zr_pc_cliente.
    "! REPORTED do BO Cliente
    TYPES ty_reported  TYPE RESPONSE FOR REPORTED EARLY zr_pc_cliente.
    "! Endereços lidos pela associação _Endereco
    TYPES tt_enderecos TYPE TABLE FOR READ RESULT zr_pc_cliente\\Cliente\_Endereco.

    CONSTANTS:
      "! CEPs já validados no double (a determination não consulta o ViaCEP)
      BEGIN OF c_cep,
        "! Av. Paulista, São Paulo/SP
        paulista   TYPE c LENGTH 8 VALUE '01310100',
        "! Rua da Assembleia, Rio de Janeiro/RJ
        assembleia TYPE c LENGTH 8 VALUE '20040020',
      END OF c_cep.

    "! Doubles das entidades CDS (Cliente, Endereço, CodeList e Pedido)
    CLASS-DATA go_cds TYPE REF TO if_cds_test_environment.
    "! Doubles das tabelas de rascunho
    CLASS-DATA go_sql TYPE REF TO if_osql_test_environment.

    "! Cria os doubles (uma vez por classe de teste).
    CLASS-METHODS criar_ambiente.
    "! Destrói os doubles ao final da classe de teste.
    CLASS-METHODS destruir_ambiente.
    "! Limpa os doubles antes de cada teste.
    CLASS-METHODS limpar_ambiente.

    "! Cliente ativo já gravado (no double).
    METHODS semear_cliente
      IMPORTING iv_cpf            TYPE csequence DEFAULT '11144477735'
      RETURNING VALUE(rv_cliente) TYPE sysuuid_x16.
    "! Endereço ativo validado (CepStatus V) já gravado (no double).
    METHODS semear_endereco
      IMPORTING iv_cliente         TYPE sysuuid_x16
                iv_cep             TYPE csequence
                iv_principal       TYPE abap_boolean DEFAULT abap_true
                iv_cep_status      TYPE csequence DEFAULT zif_pc_constants=>c_status_cep-validado
      RETURNING VALUE(rv_endereco) TYPE sysuuid_x16.
    "! Outro cliente com os dois CEPs de c_cep validados: base da busca local de CEP.
    METHODS semear_ceps_conhecidos.
    "! Pedido ativo do cliente (no double).
    METHODS semear_pedido
      IMPORTING iv_cliente TYPE sysuuid_x16
                iv_status  TYPE csequence DEFAULT zif_pc_constants=>c_status_pedido-aberto.
    "! Pedido ainda em rascunho do cliente (tabela draft no double).
    METHODS semear_pedido_rascunho
      IMPORTING iv_cliente TYPE sysuuid_x16.

    "! Rascunho de cliente novo; os valores padrão formam um cliente válido.
    METHODS criar_rascunho
      IMPORTING iv_cpf            TYPE csequence DEFAULT '52998224725'
                iv_nome           TYPE csequence DEFAULT 'Maria QA'
                iv_email          TYPE csequence DEFAULT 'maria@teste.com'
                iv_telefone       TYPE csequence DEFAULT '11987654321'
                iv_genero         TYPE csequence OPTIONAL
                iv_nascimento     TYPE d DEFAULT '19900101'
      RETURNING VALUE(rv_cliente) TYPE sysuuid_x16.
    "! Endereços novos no rascunho do cliente, um por CEP.
    METHODS criar_enderecos
      IMPORTING iv_cliente TYPE sysuuid_x16
                it_ceps    TYPE string_table
                iv_numero  TYPE csequence DEFAULT '10'.
    "! Endereços do rascunho do cliente, lidos pelo BO.
    METHODS ler_enderecos
      IMPORTING iv_cliente          TYPE sysuuid_x16
      RETURNING VALUE(rt_enderecos) TYPE tt_enderecos.
    "! Executa o Prepare (validations do Save) no rascunho do cliente.
    METHODS preparar
      IMPORTING iv_cliente  TYPE sysuuid_x16
      EXPORTING es_failed   TYPE ty_failed
                es_reported TYPE ty_reported.
ENDCLASS.


CLASS lcl_base_cliente IMPLEMENTATION.

  METHOD criar_ambiente.
    go_cds = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_PC_CLIENTE' )
                                         ( i_for_entity = 'ZR_PC_ENDERECO' )
                                         ( i_for_entity = 'ZR_PC_CODELIST' )
                                         ( i_for_entity = 'ZR_PC_PEDIDO' ) ) ).
    go_sql = cl_osql_test_environment=>create(
               i_dependency_list = VALUE #( ( 'ZTA_PC_CLIENTE_D' ) ( 'ZTA_PC_ENDEREC_D' ) ( 'ZTA_PC_PEDIDO_D' ) ) ).
  ENDMETHOD.

  METHOD destruir_ambiente.
    go_cds->destroy( ).
    go_sql->destroy( ).
  ENDMETHOD.

  METHOD limpar_ambiente.
    go_cds->clear_doubles( ).
    go_sql->clear_doubles( ).
  ENDMETHOD.

  METHOD semear_cliente.
    DATA lt_cli TYPE STANDARD TABLE OF zta_pc_cliente WITH EMPTY KEY.

    rv_cliente = cl_system_uuid=>create_uuid_x16_static( ).
    lt_cli = VALUE #( ( client = sy-mandt cliente_uuid = rv_cliente cpf = iv_cpf nome = 'Cliente QA'
                        email = 'qa@teste.com' telefone = '11999999999' data_nascimento = '19900101'
                        cliente_ativo = abap_true score_cliente = 50 ) ).
    go_cds->insert_test_data( lt_cli ).
  ENDMETHOD.

  METHOD semear_endereco.
    DATA lt_end TYPE STANDARD TABLE OF zta_pc_endereco WITH EMPTY KEY.

    rv_endereco = cl_system_uuid=>create_uuid_x16_static( ).
    lt_end = VALUE #( ( client = sy-mandt endereco_uuid = rv_endereco cep = iv_cep cliente_uuid = iv_cliente
                        logradouro = COND #( WHEN iv_cep = c_cep-paulista THEN 'Av Paulista' ELSE 'Rua da Assembleia' )
                        numero     = '1'
                        bairro     = COND #( WHEN iv_cep = c_cep-paulista THEN 'Bela Vista' ELSE 'Centro' )
                        cidade     = COND #( WHEN iv_cep = c_cep-paulista THEN 'Sao Paulo' ELSE 'Rio de Janeiro' )
                        uf         = COND #( WHEN iv_cep = c_cep-paulista THEN 'SP' ELSE 'RJ' )
                        estado     = COND #( WHEN iv_cep = c_cep-paulista THEN 'Sao Paulo' ELSE 'Rio de Janeiro' )
                        cep_status = iv_cep_status
                        endereco_principal = iv_principal ) ).
    go_cds->insert_test_data( lt_end ).
  ENDMETHOD.

  METHOD semear_ceps_conhecidos.
    DATA(lv_outro) = semear_cliente( '12345678909' ).
    semear_endereco( iv_cliente = lv_outro iv_cep = c_cep-paulista ).
    semear_endereco( iv_cliente = lv_outro iv_cep = c_cep-assembleia iv_principal = abap_false ).
  ENDMETHOD.

  METHOD semear_pedido.
    DATA lt_ped TYPE STANDARD TABLE OF zta_pc_pedido WITH EMPTY KEY.

    lt_ped = VALUE #( ( client = sy-mandt pedido_uuid = cl_system_uuid=>create_uuid_x16_static( )
                        numero_pedido = '9999999999' cliente_uuid = iv_cliente
                        status_pedido = iv_status
                        status_pagamento = zif_pc_constants=>c_status_pagamento-pendente currency = 'BRL' ) ).
    go_cds->insert_test_data( lt_ped ).
  ENDMETHOD.

  METHOD semear_pedido_rascunho.
    DATA lt_ped TYPE STANDARD TABLE OF zta_pc_pedido_d WITH EMPTY KEY.

    lt_ped = VALUE #( ( mandt = sy-mandt pedidouuid = cl_system_uuid=>create_uuid_x16_static( )
                        clienteuuid = iv_cliente statuspedido = zif_pc_constants=>c_status_pedido-aberto ) ).
    go_sql->insert_test_data( lt_ped ).
  ENDMETHOD.

  METHOD criar_rascunho.
    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        CREATE FIELDS ( Cpf Nome Email Telefone Genero DataNascimento )
        WITH VALUE #( ( %cid = 'CLI' %is_draft = if_abap_behv=>mk-on
                        Cpf = iv_cpf Nome = iv_nome Email = iv_email Telefone = iv_telefone
                        Genero = iv_genero DataNascimento = iv_nascimento ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao criar o rascunho do cliente' ).
    rv_cliente = ls_mapped-cliente[ 1 ]-ClienteUUID.
  ENDMETHOD.

  METHOD criar_enderecos.
    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        CREATE BY \_Endereco FIELDS ( Cep Numero )
        WITH VALUE #( ( %tky    = VALUE #( ClienteUUID = iv_cliente %is_draft = if_abap_behv=>mk-on )
                        %target = VALUE #( FOR lv_cep IN it_ceps INDEX INTO lv_idx
                                           ( %cid = |END{ lv_idx }| %is_draft = if_abap_behv=>mk-on
                                             Cep = lv_cep Numero = iv_numero ) ) ) )
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Falha ao criar os endereços no rascunho' ).
  ENDMETHOD.

  METHOD ler_enderecos.
    READ ENTITIES OF zr_pc_cliente
      ENTITY Cliente BY \_Endereco
        ALL FIELDS WITH VALUE #( ( ClienteUUID = iv_cliente %is_draft = if_abap_behv=>mk-on ) )
      RESULT rt_enderecos.
  ENDMETHOD.

  METHOD preparar.
    " EXECUTE Prepare por EML não devolve as falhas das validations nesta LUW;
    " o Activate executa o Prepare do rascunho e devolve FAILED/REPORTED.
    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Activate FROM VALUE #( ( %cid = 'ACT' %key-ClienteUUID = iv_cliente ) )
      FAILED es_failed
      REPORTED es_reported.
  ENDMETHOD.

ENDCLASS.


*"* Cliente: determinations da criação e validations do Save.
"! Determinations da criação e validations do Save do cliente.
CLASS ltcl_cliente_validacoes DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_cliente
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Cria os doubles da classe.
    CLASS-METHODS class_setup.
    "! Destrói os doubles da classe.
    CLASS-METHODS class_teardown.
    "! Doubles limpos e CodeList de gênero semeada antes de cada teste.
    METHODS setup.

    "! Rascunho válido passa no Prepare sem erros.
    METHODS cliente_valido_sem_erros    FOR TESTING.
    "! Cliente novo nasce ativo, com Score entre 0 e 100.
    METHODS nasce_ativo_com_score       FOR TESTING.
    "! Telefone vira só dígitos e e-mail fica em minúsculas.
    METHODS normaliza_telefone_e_email  FOR TESTING.
    "! CPF com dígito verificador errado é recusado (001).
    METHODS cpf_invalido                FOR TESTING.
    "! CPF já cadastrado é recusado (002).
    METHODS cpf_duplicado               FOR TESTING.
    "! E-mail sem formato válido é recusado (024).
    METHODS email_invalido              FOR TESTING.
    "! Telefone fora de 10/11 dígitos é recusado (026).
    METHODS telefone_invalido           FOR TESTING.
    "! Data de nascimento futura é recusada (025).
    METHODS nascimento_futuro           FOR TESTING.
    "! Gênero fora da CodeList é recusado (041).
    METHODS genero_fora_da_codelist     FOR TESTING.
    "! Gênero da CodeList é aceito.
    METHODS genero_da_codelist          FOR TESTING.
    "! Foto em formato não suportado é recusada (009).
    METHODS foto_formato_invalido       FOR TESTING.
ENDCLASS.


CLASS ltcl_cliente_validacoes IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    limpar_ambiente( ).
    " CodeList de gênero usada por ValidarGenero
    DATA lt_cod TYPE STANDARD TABLE OF zta_pc_codelist WITH EMPTY KEY.
    lt_cod = VALUE #( ( client = sy-mandt lista = zif_pc_constants=>c_codelist-genero codigo = 'FEMININO'
                        descricao = 'Feminino' ordem = 1 ) ).
    go_cds->insert_test_data( lt_cod ).
  ENDMETHOD.

  METHOD cliente_valido_sem_erros.
    DATA(lv_cli) = criar_rascunho( ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_initial( act = ls_failed-cliente
                                         msg = 'Cliente com dados válidos não deve ser bloqueado' ).
    cl_abap_unit_assert=>assert_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                         msg = 'Nenhuma mensagem esperada' ).
  ENDMETHOD.

  METHOD nasce_ativo_com_score.
    DATA(lv_cli) = criar_rascunho( ).

    READ ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        FIELDS ( ClienteAtivo ScoreCliente )
        WITH VALUE #( ( ClienteUUID = lv_cli %is_draft = if_abap_behv=>mk-on ) )
      RESULT DATA(lt_cli).

    cl_abap_unit_assert=>assert_equals( act = lt_cli[ 1 ]-ClienteAtivo exp = abap_true msg = 'Cliente novo nasce ativo' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lt_cli[ 1 ]-ScoreCliente BETWEEN 0 AND 100 )
                                      msg = |Score sorteado deve ficar entre 0 e 100: { lt_cli[ 1 ]-ScoreCliente }| ).
  ENDMETHOD.

  METHOD normaliza_telefone_e_email.
    DATA(lv_cli) = criar_rascunho( iv_telefone = '11-98765432'
                                   iv_email    = ' Maria.QA@Teste.COM' ).

    READ ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        FIELDS ( Telefone Email )
        WITH VALUE #( ( ClienteUUID = lv_cli %is_draft = if_abap_behv=>mk-on ) )
      RESULT DATA(lt_cli).

    cl_abap_unit_assert=>assert_equals( act = lt_cli[ 1 ]-Telefone exp = '1198765432'
                                        msg = 'Telefone é gravado só com dígitos' ).
    cl_abap_unit_assert=>assert_equals( act = lt_cli[ 1 ]-Email exp = 'maria.qa@teste.com'
                                        msg = 'E-mail é gravado em minúsculas, sem espaços' ).
  ENDMETHOD.

  METHOD cpf_invalido.
    DATA(lv_cli) = criar_rascunho( iv_cpf = '12345678900' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-cliente msg = 'CPF com DV errado deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                                msg = 'Mensagem 001 (CPF inválido)' ).
  ENDMETHOD.

  METHOD cpf_duplicado.
    semear_cliente( '52998224725' ).
    DATA(lv_cli) = criar_rascunho( iv_cpf = '52998224725' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-cliente msg = 'CPF já cadastrado deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                                msg = 'Mensagem 002 (CPF duplicado)' ).
  ENDMETHOD.

  METHOD email_invalido.
    DATA(lv_cli) = criar_rascunho( iv_email = 'maria.teste.com' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-cliente msg = 'E-mail sem @ deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                                msg = 'Mensagem 024 (e-mail inválido)' ).
  ENDMETHOD.

  METHOD telefone_invalido.
    DATA(lv_cli) = criar_rascunho( iv_telefone = '119999999' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-cliente msg = 'Telefone com 9 dígitos deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                                msg = 'Mensagem 026 (telefone inválido)' ).
  ENDMETHOD.

  METHOD nascimento_futuro.
    DATA(lv_futuro) = CONV d( cl_abap_context_info=>get_system_date( ) + 30 ).
    DATA(lv_cli) = criar_rascunho( iv_nascimento = lv_futuro ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-cliente msg = 'Nascimento no futuro deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                                msg = 'Mensagem 025 (data de nascimento futura)' ).
  ENDMETHOD.

  METHOD genero_fora_da_codelist.
    DATA(lv_cli) = criar_rascunho( iv_genero = 'XPTO' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-cliente msg = 'Gênero fora da CodeList deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                                msg = 'Mensagem 041 (valor inválido)' ).
  ENDMETHOD.

  METHOD genero_da_codelist.
    DATA(lv_cli) = criar_rascunho( iv_genero = 'FEMININO' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_initial( act = ls_failed-cliente msg = 'Gênero da CodeList é aceito' ).
  ENDMETHOD.

  METHOD foto_formato_invalido.
    DATA(lv_cli) = criar_rascunho( ).
    " Bytes de PNG declarados como GIF: só JPEG, PNG e WEBP são aceitos
    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        UPDATE FIELDS ( FotoCliente FotoMimeType FotoFileName )
        WITH VALUE #( ( %tky         = VALUE #( ClienteUUID = lv_cli %is_draft = if_abap_behv=>mk-on )
                        FotoCliente  = CONV xstring( `89504E470D0A1A0A0000000D49484452` )
                        FotoMimeType = 'image/gif'
                        FotoFileName = 'cliente.gif' ) )
      FAILED DATA(ls_failed_upd).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_upd msg = 'Falha ao anexar a foto no rascunho' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-cliente msg = 'Foto GIF deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                                msg = 'Mensagem 009 (formato de foto inválido)' ).
  ENDMETHOD.

ENDCLASS.


*"* Endereço: preenchimento pelo CEP, endereço principal e validations do Save.
"! Endereços do cliente: CEP, número, endereço principal (determination,
"! action DefinirEnderecoPrincipal e seu precheck).
CLASS ltcl_cliente_endereco DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_cliente
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Cria os doubles da classe.
    CLASS-METHODS class_setup.
    "! Destrói os doubles da classe.
    CLASS-METHODS class_teardown.
    "! Doubles limpos e CEPs conhecidos semeados antes de cada teste.
    METHODS setup.

    "! CEP já validado no cadastro preenche logradouro, bairro, cidade e UF.
    METHODS cep_conhecido_preenche_dados  FOR TESTING.
    "! Com dois endereços novos, só um vira o principal.
    METHODS um_unico_endereco_principal   FOR TESTING.
    "! CEP sem 8 dígitos é marcado inválido e bloqueia o save (007).
    METHODS cep_incompleto_invalido       FOR TESTING.
    "! CEP repetido no mesmo cliente bloqueia o save (047).
    METHODS cep_repetido_no_cliente       FOR TESTING.
    "! Endereço sem número bloqueia o save (008).
    METHODS numero_obrigatorio            FOR TESTING.

    "! Executa DefinirEnderecoPrincipal nos endereços ativos informados
    "! (o segundo é opcional).
    METHODS definir_principal
      IMPORTING iv_endereco  TYPE sysuuid_x16
                iv_endereco2 TYPE sysuuid_x16 OPTIONAL
      EXPORTING es_failed    TYPE ty_failed
                es_reported  TYPE ty_reported.
    "! Precheck: dois endereços do mesmo cliente na mesma chamada (051).
    METHODS principal_dois_enderecos      FOR TESTING.
    "! Precheck: endereço que já é o principal (052).
    METHODS principal_ja_definido         FOR TESTING.
    "! Precheck: endereço com CEP não validado (053).
    METHODS principal_cep_nao_validado    FOR TESTING.
    "! Um único endereço válido passa no precheck e vira o principal.
    METHODS principal_um_endereco_valido  FOR TESTING.
ENDCLASS.


CLASS ltcl_cliente_endereco IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    limpar_ambiente( ).
    semear_ceps_conhecidos( ).
  ENDMETHOD.

  METHOD cep_conhecido_preenche_dados.
    DATA(lv_cli) = criar_rascunho( ).
    criar_enderecos( iv_cliente = lv_cli it_ceps = VALUE #( ( CONV #( c_cep-paulista ) ) ) ).

    DATA(lt_end) = ler_enderecos( lv_cli ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_end ) exp = 1 msg = 'Um endereço no rascunho' ).
    DATA(ls_end) = lt_end[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_end-Logradouro exp = 'Av Paulista' msg = 'Logradouro do CEP cadastrado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_end-Cidade exp = 'Sao Paulo' msg = 'Cidade do CEP cadastrado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_end-Uf exp = 'SP' msg = 'UF do CEP cadastrado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_end-CepStatus exp = zif_pc_constants=>c_status_cep-validado
                                        msg = 'CEP já cadastrado conta como validado' ).
    cl_abap_unit_assert=>assert_equals( act = ls_end-EnderecoPrincipal exp = abap_true
                                        msg = 'O primeiro endereço vira o principal' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) ).
    cl_abap_unit_assert=>assert_initial( act = ls_failed-endereco msg = 'Endereço completo não deve bloquear' ).
  ENDMETHOD.

  METHOD um_unico_endereco_principal.
    DATA(lv_cli) = criar_rascunho( ).
    criar_enderecos( iv_cliente = lv_cli
                     it_ceps    = VALUE #( ( CONV #( c_cep-paulista ) ) ( CONV #( c_cep-assembleia ) ) ) ).

    DATA(lt_end) = ler_enderecos( lv_cli ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_end ) exp = 2 msg = 'Dois endereços no rascunho' ).
    cl_abap_unit_assert=>assert_equals(
      act = REDUCE i( INIT n = 0 FOR e IN lt_end WHERE ( EnderecoPrincipal = abap_true ) NEXT n = n + 1 )
      exp = 1
      msg = 'Exatamente um endereço principal por cliente' ).
  ENDMETHOD.

  METHOD cep_incompleto_invalido.
    DATA(lv_cli) = criar_rascunho( ).
    criar_enderecos( iv_cliente = lv_cli it_ceps = VALUE #( ( `0131` ) ) ).

    DATA(lt_end) = ler_enderecos( lv_cli ).
    cl_abap_unit_assert=>assert_equals( act = lt_end[ 1 ]-CepStatus
                                        exp = zif_pc_constants=>c_status_cep-invalido
                                        msg = 'CEP sem 8 dígitos é marcado inválido sem consultar o ViaCEP' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_failed msg = 'CEP inválido deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                                msg = 'Mensagem 007 (CEP inválido)' ).
  ENDMETHOD.

  METHOD cep_repetido_no_cliente.
    DATA(lv_cli) = criar_rascunho( ).
    criar_enderecos( iv_cliente = lv_cli
                     it_ceps    = VALUE #( ( CONV #( c_cep-paulista ) ) ( CONV #( c_cep-paulista ) ) ) ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed msg = 'CEP repetido no mesmo cliente deve bloquear' ).
    cl_abap_unit_assert=>assert_not_initial( act = lcl_msgs=>numeros( ls_reported-cliente )
                                                msg = 'Mensagem 047 (CEP duplicado no cliente)' ).
  ENDMETHOD.

  METHOD numero_obrigatorio.
    DATA(lv_cli) = criar_rascunho( ).
    criar_enderecos( iv_cliente = lv_cli it_ceps = VALUE #( ( CONV #( c_cep-paulista ) ) ) iv_numero = '' ).

    preparar( EXPORTING iv_cliente = lv_cli IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed msg = 'Endereço sem número deve bloquear' ).
  ENDMETHOD.

  METHOD definir_principal.
    DATA lt_keys TYPE TABLE FOR ACTION IMPORT zr_pc_cliente\\Endereco~DefinirEnderecoPrincipal.

    lt_keys = VALUE #( ( %key-EnderecoUUID = iv_endereco %is_draft = if_abap_behv=>mk-off ) ).
    IF iv_endereco2 IS NOT INITIAL.
      APPEND VALUE #( %key-EnderecoUUID = iv_endereco2 %is_draft = if_abap_behv=>mk-off ) TO lt_keys.
    ENDIF.

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Endereco
        EXECUTE DefinirEnderecoPrincipal FROM lt_keys
      FAILED es_failed
      REPORTED es_reported.
  ENDMETHOD.

  METHOD principal_dois_enderecos.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_end1) = semear_endereco( iv_cliente = lv_cli iv_cep = c_cep-paulista iv_principal = abap_false ).
    DATA(lv_end2) = semear_endereco( iv_cliente = lv_cli iv_cep = c_cep-assembleia iv_principal = abap_false ).

    definir_principal( EXPORTING iv_endereco = lv_end1 iv_endereco2 = lv_end2
                       IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_failed-endereco ) exp = 2
                                        msg = 'Dois endereços do mesmo cliente: ambos recusados no precheck' ).
    DATA(lt_numeros) = lcl_msgs=>numeros( ls_reported-endereco ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_numeros[ table_line = '051' ] ) )
                                      msg = 'Mensagem 051 (selecione apenas um endereço)' ).
  ENDMETHOD.

  METHOD principal_ja_definido.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_end) = semear_endereco( iv_cliente = lv_cli iv_cep = c_cep-paulista ).

    definir_principal( EXPORTING iv_endereco = lv_end
                       IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-endereco msg = 'Endereço já principal deve ser recusado' ).
    DATA(lt_numeros) = lcl_msgs=>numeros( ls_reported-endereco ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_numeros[ table_line = '052' ] ) )
                                      msg = 'Mensagem 052 (já é o principal)' ).
  ENDMETHOD.

  METHOD principal_cep_nao_validado.
    DATA(lv_cli) = semear_cliente( ).
    semear_endereco( iv_cliente = lv_cli iv_cep = c_cep-paulista ).
    DATA(lv_end) = semear_endereco( iv_cliente    = lv_cli
                                    iv_cep        = c_cep-assembleia
                                    iv_principal  = abap_false
                                    iv_cep_status = zif_pc_constants=>c_status_cep-invalido ).

    definir_principal( EXPORTING iv_endereco = lv_end
                       IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-endereco msg = 'CEP não validado deve ser recusado' ).
    DATA(lt_numeros) = lcl_msgs=>numeros( ls_reported-endereco ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_numeros[ table_line = '053' ] ) )
                                      msg = 'Mensagem 053 (CEP não validado)' ).
  ENDMETHOD.

  METHOD principal_um_endereco_valido.
    DATA(lv_cli) = semear_cliente( ).
    DATA(lv_atual) = semear_endereco( iv_cliente = lv_cli iv_cep = c_cep-paulista ).
    DATA(lv_novo)  = semear_endereco( iv_cliente = lv_cli iv_cep = c_cep-assembleia iv_principal = abap_false ).

    definir_principal( EXPORTING iv_endereco = lv_novo IMPORTING es_failed = DATA(ls_failed) ).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Um endereço válido passa no precheck' ).

    READ ENTITIES OF zr_pc_cliente
      ENTITY Endereco
        FIELDS ( EnderecoPrincipal )
        WITH VALUE #( ( EnderecoUUID = lv_novo  %is_draft = if_abap_behv=>mk-off )
                      ( EnderecoUUID = lv_atual %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_end).

    cl_abap_unit_assert=>assert_equals( act = VALUE abap_boolean( lt_end[ EnderecoUUID = lv_novo ]-EnderecoPrincipal OPTIONAL )
                                        exp = abap_true
                                        msg = 'Endereço escolhido vira o principal' ).
    cl_abap_unit_assert=>assert_equals( act = VALUE abap_boolean( lt_end[ EnderecoUUID = lv_atual ]-EnderecoPrincipal OPTIONAL )
                                        exp = abap_false
                                        msg = 'Principal anterior deixa de ser' ).
  ENDMETHOD.

ENDCLASS.


*"* Exclusão: bloqueada para cliente com pedido ativo ou em rascunho
*"* (feature control de delete + precheck).
"! Exclusão do cliente: bloqueada com pedido ativo ou em rascunho (feature
"! control de delete + precheck).
CLASS ltcl_cliente_exclusao DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_cliente
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Cria os doubles da classe.
    CLASS-METHODS class_setup.
    "! Destrói os doubles da classe.
    CLASS-METHODS class_teardown.
    "! Doubles limpos antes de cada teste.
    METHODS setup.
    "! Exclui o cliente ativo; devolve abap_true se a exclusão foi recusada.
    METHODS excluir
      IMPORTING iv_cliente       TYPE sysuuid_x16
      RETURNING VALUE(rv_falhou) TYPE abap_boolean.
    "! abap_true se o cliente ativo ainda pode ser lido pelo BO.
    METHODS existe
      IMPORTING iv_cliente       TYPE sysuuid_x16
      RETURNING VALUE(rv_existe) TYPE abap_boolean.

    "! Cliente sem pedido pode ser excluído.
    METHODS exclui_cliente_sem_pedido     FOR TESTING.
    "! Cliente com pedido gravado não pode ser excluído (004).
    METHODS bloqueia_com_pedido_ativo     FOR TESTING.
    "! Pedido ainda em rascunho também impede a exclusão (004).
    METHODS bloqueia_com_pedido_rascunho  FOR TESTING.
ENDCLASS.


CLASS ltcl_cliente_exclusao IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    limpar_ambiente( ).
  ENDMETHOD.

  METHOD excluir.
    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        DELETE FROM VALUE #( ( %key-ClienteUUID = iv_cliente %is_draft = if_abap_behv=>mk-off ) )
      FAILED DATA(ls_failed).
    rv_falhou = xsdbool( ls_failed-cliente IS NOT INITIAL ).
  ENDMETHOD.

  METHOD existe.
    READ ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        FIELDS ( ClienteUUID ) WITH VALUE #( ( ClienteUUID = iv_cliente %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_cli).
    rv_existe = xsdbool( lt_cli IS NOT INITIAL ).
  ENDMETHOD.

  METHOD exclui_cliente_sem_pedido.
    DATA(lv_cli) = semear_cliente( ).
    semear_endereco( iv_cliente = lv_cli iv_cep = c_cep-paulista ).

    cl_abap_unit_assert=>assert_false( act = excluir( lv_cli ) msg = 'Cliente sem pedido pode ser excluído' ).
    cl_abap_unit_assert=>assert_false( act = existe( lv_cli ) msg = 'Cliente excluído não deve ser lido' ).
  ENDMETHOD.

  METHOD bloqueia_com_pedido_ativo.
    DATA(lv_cli) = semear_cliente( ).
    semear_pedido( lv_cli ).

    cl_abap_unit_assert=>assert_true( act = excluir( lv_cli ) msg = 'Cliente com pedido não pode ser excluído' ).
    cl_abap_unit_assert=>assert_true( act = existe( lv_cli ) msg = 'Cliente deve continuar cadastrado' ).
  ENDMETHOD.

  METHOD bloqueia_com_pedido_rascunho.
    DATA(lv_cli) = semear_cliente( ).
    semear_pedido_rascunho( lv_cli ).

    cl_abap_unit_assert=>assert_true( act = excluir( lv_cli )
                                      msg = 'Pedido ainda em rascunho também impede a exclusão' ).
    cl_abap_unit_assert=>assert_true( act = existe( lv_cli ) msg = 'Cliente deve continuar cadastrado' ).
  ENDMETHOD.

ENDCLASS.


*"* Inativação: bloqueada para cliente com pedido em andamento (aberto,
*"* aguardando aprovação, processando reembolso ou rascunho), já no
*"* precheck do UPDATE; reativar é sempre permitido.
"! Inativação do cliente (mensagem 050), recusada já no precheck do UPDATE.
CLASS ltcl_cliente_inativacao DEFINITION FINAL FOR TESTING INHERITING FROM lcl_base_cliente
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Cria os doubles da classe.
    CLASS-METHODS class_setup.
    "! Destrói os doubles da classe.
    CLASS-METHODS class_teardown.
    "! Descarta o buffer transacional do teste anterior e limpa os doubles.
    METHODS setup.
    "! Edita o cliente ativo e altera ClienteAtivo no rascunho (UPDATE).
    METHODS alterar_ativo
      IMPORTING iv_cliente  TYPE sysuuid_x16
                iv_ativo    TYPE abap_boolean
      EXPORTING es_failed   TYPE ty_failed
                es_reported TYPE ty_reported.

    "! Cliente com pedido ABERTO não pode ser inativado (050).
    METHODS bloqueia_com_pedido_aberto     FOR TESTING.
    "! Pedido em rascunho também impede a inativação.
    METHODS bloqueia_com_pedido_rascunho   FOR TESTING.
    "! Pedido encerrado (FINALIZADO) não impede a inativação.
    METHODS permite_com_pedido_finalizado  FOR TESTING.
    "! Cliente sem pedido pode ser inativado.
    METHODS permite_sem_pedido             FOR TESTING.
    "! Reativar o cliente não passa pela regra de bloqueio.
    METHODS permite_reativar               FOR TESTING.
ENDCLASS.


CLASS ltcl_cliente_inativacao IMPLEMENTATION.

  METHOD class_setup.
    criar_ambiente( ).
  ENDMETHOD.

  METHOD class_teardown.
    destruir_ambiente( ).
  ENDMETHOD.

  METHOD setup.
    " O Edit recusado no teste anterior fica pendente no buffer transacional;
    " sem o rollback ele seria executado sobre dados já limpos do double.
    ROLLBACK ENTITIES.
    limpar_ambiente( ).
  ENDMETHOD.

  METHOD alterar_ativo.
    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE Edit FROM VALUE #( ( %cid = 'ED' %key-ClienteUUID = iv_cliente ) )
      FAILED DATA(ls_failed_ed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed_ed msg = 'Edit do cliente falhou' ).

    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        UPDATE FIELDS ( ClienteAtivo )
        WITH VALUE #( ( %tky = VALUE #( ClienteUUID = iv_cliente %is_draft = if_abap_behv=>mk-on )
                        ClienteAtivo = iv_ativo ) )
      FAILED es_failed
      REPORTED es_reported.
  ENDMETHOD.

  METHOD bloqueia_com_pedido_aberto.
    DATA(lv_cli) = semear_cliente( ).
    semear_pedido( lv_cli ).

    alterar_ativo( EXPORTING iv_cliente = lv_cli iv_ativo = abap_false
                   IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-cliente
                                             msg = 'Cliente com pedido aberto não pode ser inativado' ).
    DATA(lt_numeros) = lcl_msgs=>numeros( ls_reported-cliente ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_numeros[ table_line = '050' ] ) )
                                      msg = 'Mensagem 050 (inativação bloqueada)' ).
  ENDMETHOD.

  METHOD bloqueia_com_pedido_rascunho.
    DATA(lv_cli) = semear_cliente( ).
    semear_pedido_rascunho( lv_cli ).

    alterar_ativo( EXPORTING iv_cliente = lv_cli iv_ativo = abap_false IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_failed-cliente
                                             msg = 'Pedido em rascunho também impede a inativação' ).
  ENDMETHOD.

  METHOD permite_com_pedido_finalizado.
    DATA(lv_cli) = semear_cliente( ).
    semear_pedido( iv_cliente = lv_cli iv_status = zif_pc_constants=>c_status_pedido-finalizado ).

    alterar_ativo( EXPORTING iv_cliente = lv_cli iv_ativo = abap_false IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Pedido encerrado não impede a inativação' ).
  ENDMETHOD.

  METHOD permite_sem_pedido.
    DATA(lv_cli) = semear_cliente( ).

    alterar_ativo( EXPORTING iv_cliente = lv_cli iv_ativo = abap_false IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Cliente sem pedido pode ser inativado' ).
  ENDMETHOD.

  METHOD permite_reativar.
    DATA(lv_cli) = semear_cliente( ).
    semear_pedido( lv_cli ).

    alterar_ativo( EXPORTING iv_cliente = lv_cli iv_ativo = abap_true IMPORTING es_failed = DATA(ls_failed) ).

    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Reativar não passa pela regra de bloqueio' ).
  ENDMETHOD.

ENDCLASS.
