*"* Test Classes da classe ZCL_PC_VE_CLIENTE (virtual elements de ZC_PC_CLIENTE_APP)
*"* A classe é chamada pelo SADL; aqui os dois métodos da interface são
*"* chamados diretamente, sem banco.

CLASS ltcl_ve_cliente DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES tt_cliente TYPE STANDARD TABLE OF zc_pc_cliente_app WITH EMPTY KEY.

    DATA mo_cut TYPE REF TO if_sadl_exit_calc_element_read.

    METHODS setup.
    "! Calcula os quatro virtual elements para as linhas informadas.
    METHODS calcular
      IMPORTING it_original    TYPE tt_cliente
      RETURNING VALUE(rt_calc) TYPE tt_cliente
      RAISING   cx_static_check.
    METHODS criticidade
      IMPORTING iv_score             TYPE zc_pc_cliente_app-ScoreCliente
      RETURNING VALUE(rv_criticidade) TYPE zc_pc_cliente_app-ScoreCriticality
      RAISING   cx_static_check.

    METHODS cpf_formatado                FOR TESTING RAISING cx_static_check.
    METHODS telefone_formatado           FOR TESTING RAISING cx_static_check.
    METHODS score_em_percentual          FOR TESTING RAISING cx_static_check.
    METHODS criticidade_vermelha_ate_40  FOR TESTING RAISING cx_static_check.
    METHODS criticidade_amarela          FOR TESTING RAISING cx_static_check.
    METHODS criticidade_verde_desde_70   FOR TESTING RAISING cx_static_check.
    METHODS varias_linhas_na_ordem       FOR TESTING RAISING cx_static_check.
    METHODS elementos_originais          FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_ve_cliente IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_pc_ve_cliente( ).
  ENDMETHOD.

  METHOD calcular.
    mo_cut->calculate( EXPORTING it_original_data           = it_original
                                 it_requested_calc_elements = VALUE #( ( `CPFFORMATADO` )
                                                                       ( `TELEFONEFORMATADO` )
                                                                       ( `SCOREUNIDADE` )
                                                                       ( `SCORECRITICALITY` ) )
                       CHANGING  ct_calculated_data         = rt_calc ).
  ENDMETHOD.

  METHOD criticidade.
    rv_criticidade = calcular( VALUE #( ( ScoreCliente = iv_score ) ) )[ 1 ]-ScoreCriticality.
  ENDMETHOD.

  METHOD cpf_formatado.
    DATA(lt_calc) = calcular( VALUE #( ( Cpf = '52998224725' ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lt_calc[ 1 ]-CpfFormatado exp = '529.982.247-25'
                                        msg = 'CPF gravado só com dígitos é exibido com máscara' ).
  ENDMETHOD.

  METHOD telefone_formatado.
    DATA(lt_calc) = calcular( VALUE #( ( Telefone = '11987654321' ) ( Telefone = '1132654321' ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lt_calc[ 1 ]-TelefoneFormatado exp = '(11) 98765-4321' msg = 'Celular' ).
    cl_abap_unit_assert=>assert_equals( act = lt_calc[ 2 ]-TelefoneFormatado exp = '(11) 3265-4321' msg = 'Fixo' ).
  ENDMETHOD.

  METHOD score_em_percentual.
    cl_abap_unit_assert=>assert_equals( act = calcular( VALUE #( ( ScoreCliente = 55 ) ) )[ 1 ]-ScoreUnidade
                                        exp = '%'
                                        msg = 'O score é exibido em %' ).
  ENDMETHOD.

  METHOD criticidade_vermelha_ate_40.
    cl_abap_unit_assert=>assert_equals( act = criticidade( 0 )  exp = 1 msg = 'Score 0 => vermelho' ).
    cl_abap_unit_assert=>assert_equals( act = criticidade( 40 ) exp = 1 msg = 'Score 40 ainda é vermelho' ).
  ENDMETHOD.

  METHOD criticidade_amarela.
    cl_abap_unit_assert=>assert_equals( act = criticidade( '40.01' ) exp = 2 msg = 'Acima de 40 => amarelo' ).
    cl_abap_unit_assert=>assert_equals( act = criticidade( '69.99' ) exp = 2 msg = 'Abaixo de 70 => amarelo' ).
  ENDMETHOD.

  METHOD criticidade_verde_desde_70.
    cl_abap_unit_assert=>assert_equals( act = criticidade( 70 )  exp = 3 msg = 'Score 70 => verde' ).
    cl_abap_unit_assert=>assert_equals( act = criticidade( 100 ) exp = 3 msg = 'Score 100 => verde' ).
  ENDMETHOD.

  METHOD varias_linhas_na_ordem.
    DATA(lt_calc) = calcular( VALUE #( ( Cpf = '52998224725' ScoreCliente = 10 )
                                       ( Cpf = '11144477735' ScoreCliente = 90 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_calc ) exp = 2 msg = 'Uma linha calculada por linha original' ).
    cl_abap_unit_assert=>assert_equals( act = lt_calc[ 2 ]-CpfFormatado exp = '111.444.777-35' msg = 'Ordem mantida' ).
    cl_abap_unit_assert=>assert_equals( act = lt_calc[ 2 ]-ScoreCriticality exp = 3 msg = 'Ordem mantida' ).
  ENDMETHOD.

  METHOD elementos_originais.
    " Cada virtual element pede ao SADL só o campo de que depende; a unidade é constante
    mo_cut->get_calculation_info(
      EXPORTING it_requested_calc_elements = VALUE #( ( `CPFFORMATADO` ) ( `TELEFONEFORMATADO` )
                                                      ( `SCOREUNIDADE` ) ( `SCORECRITICALITY` ) )
                iv_entity                  = `ZC_PC_CLIENTE_APP`
      IMPORTING et_requested_orig_elements = DATA(lt_originais) ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_originais ) exp = 3 msg = 'CPF, TELEFONE e SCORECLIENTE' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_originais[ table_line = `CPF` ] ) )
                                      msg = 'CpfFormatado depende de Cpf' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_originais[ table_line = `TELEFONE` ] ) )
                                      msg = 'TelefoneFormatado depende de Telefone' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_originais[ table_line = `SCORECLIENTE` ] ) )
                                      msg = 'ScoreCriticality depende de ScoreCliente' ).
  ENDMETHOD.

ENDCLASS.
