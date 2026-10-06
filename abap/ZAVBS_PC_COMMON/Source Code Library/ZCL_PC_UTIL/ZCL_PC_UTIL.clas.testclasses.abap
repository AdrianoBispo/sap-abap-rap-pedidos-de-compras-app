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
