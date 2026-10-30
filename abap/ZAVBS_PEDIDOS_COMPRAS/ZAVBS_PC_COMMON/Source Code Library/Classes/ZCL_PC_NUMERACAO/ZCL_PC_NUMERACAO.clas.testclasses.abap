*"* Test Classes da classe ZCL_PC_NUMERACAO

"! Prefixo do SKU: regra pura, sem objeto de numeração.
CLASS ltcl_prefixo DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS tres_primeiras_letras FOR TESTING.
    METHODS maiusculas_sem_espacos FOR TESTING.
    METHODS categoria_curta       FOR TESTING.
    METHODS categoria_vazia       FOR TESTING.
ENDCLASS.


CLASS ltcl_prefixo IMPLEMENTATION.

  METHOD tres_primeiras_letras.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_numeracao=>prefixo_categoria( 'ELETRONICOS' )
      exp = `ELE`
      msg = 'Prefixo usa as 3 primeiras letras da categoria' ).
  ENDMETHOD.

  METHOD maiusculas_sem_espacos.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_numeracao=>prefixo_categoria( '  informatica ' )
      exp = `INF`
      msg = 'Prefixo ignora espaços nas pontas e fica em maiúsculas' ).
  ENDMETHOD.

  METHOD categoria_curta.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_numeracao=>prefixo_categoria( 'TV' )
      exp = `TVX`
      msg = 'Categoria com menos de 3 letras é completada com X' ).
  ENDMETHOD.

  METHOD categoria_vazia.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pc_numeracao=>prefixo_categoria( '' )
      exp = `XXX`
      msg = 'Sem categoria o prefixo é XXX' ).
  ENDMETHOD.

ENDCLASS.


"! Números do objeto {@link ZPC_NR} (intervalos 01 e 02). Exigem o objeto configurado
"! {@link ZCL_PC_SETUP} e consomem números, como o registro de pedidos e itens.
CLASS ltcl_intervalos DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS numero_pedido_dez_digitos FOR TESTING RAISING cx_static_check.
    METHODS numero_pedido_sequencial  FOR TESTING RAISING cx_static_check.
    METHODS sku_formato               FOR TESTING RAISING cx_static_check.
    METHODS sku_sequencial_distinto   FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_intervalos IMPLEMENTATION.

  METHOD numero_pedido_dez_digitos.
    DATA(lv_numero) = zcl_pc_numeracao=>proximo_numero_pedido( ).

    cl_abap_unit_assert=>assert_equals( act = strlen( lv_numero ) exp = 10
                                        msg = |Número do pedido deve ter 10 posições: { lv_numero }| ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_numero CO '0123456789' )
                                      msg = |Número do pedido deve ter só dígitos: { lv_numero }| ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( CONV int8( lv_numero ) BETWEEN CONV int8( zif_pc_constants=>c_numeracao-pedido_de )
                                                AND CONV int8( zif_pc_constants=>c_numeracao-pedido_ate ) )
      msg = |Número fora do intervalo 01: { lv_numero }| ).
  ENDMETHOD.

  METHOD numero_pedido_sequencial.
    DATA(lv_primeiro) = zcl_pc_numeracao=>proximo_numero_pedido( ).
    DATA(lv_segundo)  = zcl_pc_numeracao=>proximo_numero_pedido( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( CONV int8( lv_segundo ) > CONV int8( lv_primeiro ) )
                                      msg = |Números devem crescer: { lv_primeiro } -> { lv_segundo }| ).
  ENDMETHOD.

  METHOD sku_formato.
    DATA(lv_sku) = zcl_pc_numeracao=>gerar_sku( 'ELETRONICOS' ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_sku CP 'SKU-ELE-*' )
                                      msg = |SKU deveria começar com SKU-ELE-: { lv_sku }| ).

    cl_abap_unit_assert=>assert_equals( act = strlen( lv_sku ) exp = 18
                                        msg = |SKU deve ter 18 caracteres: { lv_sku }| ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_sku+8(10) CO '0123456789' )
                                      msg = |Sequencial do SKU deve ter 10 dígitos: { lv_sku }| ).
  ENDMETHOD.

  METHOD sku_sequencial_distinto.
    DATA(lv_sku1) = zcl_pc_numeracao=>gerar_sku( 'BRINQUEDOS' ).
    DATA(lv_sku2) = zcl_pc_numeracao=>gerar_sku( 'BRINQUEDOS' ).

    cl_abap_unit_assert=>assert_differs( act = lv_sku2 exp = lv_sku1 msg = 'SKUs devem ser únicos' ).
  ENDMETHOD.

ENDCLASS.
