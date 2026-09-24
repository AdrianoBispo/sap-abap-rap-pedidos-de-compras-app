"! <p class="shorttext synchronized">Virtual elements - Cliente (CPF/telefone formatados)</p>
"! Usada por ZC_PC_CLIENTE_APP (virtual CpfFormatado / TelefoneFormatado).
"! O CPF é persistido somente com números e exibido formatado.
CLASS zcl_pc_ve_cliente DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_pc_ve_cliente IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    LOOP AT it_requested_calc_elements INTO DATA(lv_elemento).
      CASE lv_elemento.
        WHEN 'CPFFORMATADO'.
          INSERT CONV #( 'CPF' ) INTO TABLE et_requested_orig_elements.
        WHEN 'TELEFONEFORMATADO'.
          INSERT CONV #( 'TELEFONE' ) INTO TABLE et_requested_orig_elements.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_dados TYPE STANDARD TABLE OF zc_pc_cliente_app WITH DEFAULT KEY.

    lt_dados = CORRESPONDING #( it_original_data ).

    LOOP AT lt_dados ASSIGNING FIELD-SYMBOL(<ls_dado>).
      <ls_dado>-CpfFormatado      = zcl_pc_util=>formatar_cpf( <ls_dado>-Cpf ).
      <ls_dado>-TelefoneFormatado = zcl_pc_util=>formatar_telefone( <ls_dado>-Telefone ).
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_dados ).
  ENDMETHOD.

ENDCLASS.
