*"* Test Classes da classe ZCX_PC_MSG
*"* Regras puras: sem banco, sem RAP. Verifica chave T100, severidade e as
*"* variáveis &1 a &4; os textos ficam na Message Class ZPC_MSG.

CLASS ltcl_construtor DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS padrao_erro_sem_chave   FOR TESTING.
    METHODS chave_informada         FOR TESTING.
    METHODS atributos_preenchidos   FOR TESTING.
    METHODS severidade_informada    FOR TESTING.
    METHODS sucesso_severidade      FOR TESTING.
ENDCLASS.


CLASS ltcl_construtor IMPLEMENTATION.

  METHOD padrao_erro_sem_chave.
    DATA(lo_msg) = NEW zcx_pc_msg( ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_msg->if_abap_behv_message~m_severity
      exp = if_abap_behv_message=>severity-error
      msg = 'Sem severidade informada, a mensagem é de erro' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_msg->if_t100_message~t100key
      exp = if_t100_message=>default_textid
      msg = 'Sem TEXTID, usa a chave padrão da exceção' ).
  ENDMETHOD.

  METHOD chave_informada.
    DATA(lo_msg) = NEW zcx_pc_msg( textid = zif_pc_msg=>cliente_cpf_invalido ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_msg->if_t100_message~t100key-msgid
      exp = 'ZPC_MSG'
      msg = 'Todas as mensagens são da Message Class ZPC_MSG' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_msg->if_t100_message~t100key-msgno
      exp = '001'
      msg = 'CLIENTE_CPF_INVALIDO é a mensagem 001' ).
  ENDMETHOD.

  METHOD atributos_preenchidos.
    DATA(lo_msg) = NEW zcx_pc_msg( textid = zif_pc_msg=>item_estoque_insuficiente
                                   attr1  = 'SKU-ELE-0000000001'
                                   attr2  = '5'
                                   attr3  = 'C'
                                   attr4  = 'D' ).

    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr1 exp = `SKU-ELE-0000000001` msg = '&1' ).
    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr2 exp = `5` msg = '&2' ).
    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr3 exp = `C` msg = '&3' ).
    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr4 exp = `D` msg = '&4' ).
  ENDMETHOD.

  METHOD severidade_informada.
    DATA(lo_msg) = NEW zcx_pc_msg( textid   = zif_pc_msg=>cep_indisponivel
                                   severity = if_abap_behv_message=>severity-warning ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_msg->if_abap_behv_message~m_severity
      exp = if_abap_behv_message=>severity-warning
      msg = 'A severidade informada deve ser mantida' ).
  ENDMETHOD.

  METHOD sucesso_severidade.
    DATA(lo_msg) = zcx_pc_msg=>sucesso( textid = zif_pc_msg=>pedido_finalizado
                                        attr1  = '0000000042' ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_msg->if_abap_behv_message~m_severity
      exp = if_abap_behv_message=>severity-success
      msg = 'SUCESSO cria mensagem de sucesso' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_msg->if_t100_message~t100key
      exp = zif_pc_msg=>pedido_finalizado
      msg = 'SUCESSO mantém a chave informada' ).
    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr1 exp = `0000000042` msg = '&1' ).
  ENDMETHOD.

ENDCLASS.


*"* TEXTO: mensagem 049 (&1&2&3&4) com o texto distribuído em blocos de 50
*"* caracteres, porque cada variável T100 comporta só 50.
CLASS ltcl_texto_livre DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS texto_curto_um_bloco       FOR TESTING.
    METHODS texto_dividido_em_blocos   FOR TESTING.
    METHODS texto_cortado_em_200       FOR TESTING.
    METHODS texto_severidade_padrao    FOR TESTING.
    METHODS texto_severidade_informada FOR TESTING.
ENDCLASS.


CLASS ltcl_texto_livre IMPLEMENTATION.

  METHOD texto_curto_um_bloco.
    DATA(lo_msg) = zcx_pc_msg=>texto( 'Importação concluída' ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_msg->if_t100_message~t100key
      exp = zif_pc_msg=>texto_livre
      msg = 'TEXTO usa a mensagem 049' ).
    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr1 exp = `Importação concluída` msg = 'Bloco 1' ).
    cl_abap_unit_assert=>assert_initial( act = lo_msg->mv_attr2 msg = 'Bloco 2 deve ficar vazio' ).
    cl_abap_unit_assert=>assert_initial( act = lo_msg->mv_attr3 msg = 'Bloco 3 deve ficar vazio' ).
    cl_abap_unit_assert=>assert_initial( act = lo_msg->mv_attr4 msg = 'Bloco 4 deve ficar vazio' ).
  ENDMETHOD.

  METHOD texto_dividido_em_blocos.
    DATA(lv_texto) = repeat( val = `a` occ = 50 ) && repeat( val = `b` occ = 50 ) && repeat( val = `c` occ = 20 ).

    DATA(lo_msg) = zcx_pc_msg=>texto( lv_texto ).

    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr1 exp = repeat( val = `a` occ = 50 ) msg = 'Bloco 1' ).
    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr2 exp = repeat( val = `b` occ = 50 ) msg = 'Bloco 2' ).
    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr3 exp = repeat( val = `c` occ = 20 ) msg = 'Bloco 3' ).
    cl_abap_unit_assert=>assert_initial( act = lo_msg->mv_attr4 msg = 'Bloco 4 deve ficar vazio' ).
  ENDMETHOD.

  METHOD texto_cortado_em_200.
    DATA(lv_texto) = repeat( val = `a` occ = 50 ) && repeat( val = `b` occ = 50 )
                  && repeat( val = `c` occ = 50 ) && repeat( val = `d` occ = 50 )
                  && repeat( val = `e` occ = 30 ).

    DATA(lo_msg) = zcx_pc_msg=>texto( lv_texto ).

    cl_abap_unit_assert=>assert_equals( act = lo_msg->mv_attr4 exp = repeat( val = `d` occ = 50 )
                                        msg = 'O bloco 4 termina no caractere 200' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_msg->mv_attr1 && lo_msg->mv_attr2 && lo_msg->mv_attr3 && lo_msg->mv_attr4
      exp = substring( val = lv_texto len = 200 )
      msg = 'O excedente além de 200 caracteres é descartado' ).
  ENDMETHOD.

  METHOD texto_severidade_padrao.
    cl_abap_unit_assert=>assert_equals(
      act = zcx_pc_msg=>texto( 'Erro' )->if_abap_behv_message~m_severity
      exp = if_abap_behv_message=>severity-error
      msg = 'TEXTO sem severidade é erro' ).
  ENDMETHOD.

  METHOD texto_severidade_informada.
    cl_abap_unit_assert=>assert_equals(
      act = zcx_pc_msg=>texto( iv_texto    = 'Ok'
                               iv_severity = if_abap_behv_message=>severity-success )->if_abap_behv_message~m_severity
      exp = if_abap_behv_message=>severity-success
      msg = 'TEXTO mantém a severidade informada' ).
  ENDMETHOD.

ENDCLASS.
