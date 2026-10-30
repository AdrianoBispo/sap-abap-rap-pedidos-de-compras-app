*"* Test Classes da classe ZCL_PC_VIACEP (versão SAP BTP, ABAP environment)

*"* Nenhum teste chama o ViaCEP: o parse do JSON (EXTRAIR_CAMPO) e o cache da
*"* sessão são acessados como amigos locais, e CEP fora do formato é recusado
*"* antes da chamada HTTP. Mesmos testes da versão On-Premise (ZCL_PC_VIACEP_T2).
CLASS ltcl_viacep DEFINITION DEFERRED.
CLASS zcl_pc_viacep DEFINITION LOCAL FRIENDS ltcl_viacep.

CLASS ltcl_viacep DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Resposta real do ViaCEP para 01001-000 (JSON plano)
    CONSTANTS c_json TYPE string VALUE `{"cep": "01001-000", "logradouro": "Praça da Sé", "complemento": "lado ímpar", `
                                     & `"bairro": "Sé", "localidade": "São Paulo", "uf": "SP", "estado": "São Paulo", `
                                     & `"ibge": "3550308", "gia": null}`.

    METHODS setup.
    METHODS teardown.

    METHODS extrai_texto              FOR TESTING.
    METHODS extrai_literal_booleano   FOR TESTING.
    METHODS extrai_null_como_vazio    FOR TESTING.
    METHODS extrai_campo_ausente      FOR TESTING.
    METHODS extrai_texto_vazio        FOR TESTING.
    METHODS extrai_com_espacos        FOR TESTING.
    METHODS cep_curto_nao_consulta    FOR TESTING.
    METHODS cep_vazio_nao_consulta    FOR TESTING.
    METHODS cep_em_cache_com_mascara  FOR TESTING.
ENDCLASS.


CLASS ltcl_viacep IMPLEMENTATION.

  METHOD setup.
    CLEAR zcl_pc_viacep=>gt_cache.
  ENDMETHOD.

  METHOD teardown.
    CLEAR zcl_pc_viacep=>gt_cache.
  ENDMETHOD.

  METHOD extrai_texto.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_viacep=>extrair_campo( iv_json = c_json iv_campo = `logradouro` )
      exp = `Praça da Sé`
      msg = 'Valor entre aspas, com acentos' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_viacep=>extrair_campo( iv_json = c_json iv_campo = `uf` )
      exp = `SP`
      msg = 'UF' ).
  ENDMETHOD.

  METHOD extrai_literal_booleano.
    " CEP inexistente: o ViaCEP responde {"erro": true}
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_viacep=>extrair_campo( iv_json = `{"erro": true}` iv_campo = `erro` )
      exp = `true`
      msg = 'Literal sem aspas deve ser lido' ).
  ENDMETHOD.

  METHOD extrai_null_como_vazio.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_pc_viacep=>extrair_campo( iv_json = c_json iv_campo = `gia` )
      msg = 'null vira texto vazio' ).
  ENDMETHOD.

  METHOD extrai_campo_ausente.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_pc_viacep=>extrair_campo( iv_json = c_json iv_campo = `numero` )
      msg = 'Campo inexistente no JSON devolve vazio' ).
  ENDMETHOD.

  METHOD extrai_texto_vazio.
    " CEP geral de município: logradouro e bairro vêm vazios
    cl_abap_unit_assert=>assert_initial(
      act = zcl_pc_viacep=>extrair_campo( iv_json  = `{"cep": "13560-970", "logradouro": "", "bairro": ""}`
                                          iv_campo = `logradouro` )
      msg = 'Valor "" devolve vazio' ).
  ENDMETHOD.

  METHOD extrai_com_espacos.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_viacep=>extrair_campo( iv_json = `{ "uf"  :   "RJ" }` iv_campo = `uf` )
      exp = `RJ`
      msg = 'Espaços em volta dos dois-pontos são aceitos' ).
  ENDMETHOD.

  METHOD cep_curto_nao_consulta.
    DATA(ls_resultado) = zcl_pc_viacep=>consultar( '0100100' ).

    cl_abap_unit_assert=>assert_false( act = ls_resultado-valido msg = 'CEP com 7 dígitos é inválido' ).
    cl_abap_unit_assert=>assert_false( act = ls_resultado-indisponivel
                                       msg = 'Formato inválido não é indisponibilidade do serviço' ).
    cl_abap_unit_assert=>assert_initial( act = ls_resultado-endereco msg = 'Sem consulta, sem endereço' ).
    cl_abap_unit_assert=>assert_initial( act = zcl_pc_viacep=>gt_cache msg = 'Formato inválido não entra no cache' ).
  ENDMETHOD.

  METHOD cep_vazio_nao_consulta.
    cl_abap_unit_assert=>assert_false( act = zcl_pc_viacep=>consultar( '' )-valido msg = 'CEP vazio é inválido' ).
  ENDMETHOD.

  METHOD cep_em_cache_com_mascara.
    " O CEP é normalizado (só dígitos) antes da busca no cache: não há chamada HTTP
    INSERT VALUE #( cep       = `01001000`
                    resultado = VALUE #( valido   = abap_true
                                         endereco = VALUE #( cep        = `01001-000`
                                                             logradouro = `Praça da Sé`
                                                             localidade = `São Paulo`
                                                             uf         = `SP` ) ) )
           INTO TABLE zcl_pc_viacep=>gt_cache.

    DATA(ls_resultado) = zcl_pc_viacep=>consultar( '01001-000' ).

    cl_abap_unit_assert=>assert_true( act = ls_resultado-valido msg = 'Resultado deve vir do cache' ).
    cl_abap_unit_assert=>assert_equals( act = ls_resultado-endereco-localidade exp = `São Paulo` msg = 'Cidade do cache' ).
  ENDMETHOD.

ENDCLASS.
