"! <p class="shorttext synchronized">Pedidos de Compras - Apoio à importação de planilhas</p>
"! Rotinas comuns às actions ImportarPlanilha dos BOs Cliente, Item e Pedido:
"! normalização de campos que o Excel costuma estragar (zeros à esquerda),
"! conversão de texto para código de CodeList e resumo da lista de erros.
"! Constantes, tipos e métodos públicos: interface ZIF_PC_IMPORTACAO.
CLASS zcl_pc_importacao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pc_importacao.

    ALIASES normalizar_cpf FOR zif_pc_importacao~normalizar_cpf.
    ALIASES normalizar_cep FOR zif_pc_importacao~normalizar_cep.
    ALIASES converter_codelist FOR zif_pc_importacao~converter_codelist.
    ALIASES opcoes_codelist FOR zif_pc_importacao~opcoes_codelist.
    ALIASES resumir_erros FOR zif_pc_importacao~resumir_erros.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_pc_importacao IMPLEMENTATION.

  METHOD zif_pc_importacao~normalizar_cpf.
    rv_cpf = zcl_pc_util=>somente_digitos( iv_texto ).
    IF rv_cpf IS NOT INITIAL AND strlen( rv_cpf ) < 11.
      rv_cpf = |{ rv_cpf WIDTH = 11 ALIGN = RIGHT PAD = '0' }|.
    ENDIF.
  ENDMETHOD.


  METHOD zif_pc_importacao~normalizar_cep.
    rv_cep = zcl_pc_util=>somente_digitos( iv_texto ).
    IF rv_cep IS NOT INITIAL AND strlen( rv_cep ) < 8.
      rv_cep = |{ rv_cep WIDTH = 8 ALIGN = RIGHT PAD = '0' }|.
    ENDIF.
  ENDMETHOD.


  METHOD zif_pc_importacao~converter_codelist.
    DATA(lv_texto) = zcl_pc_planilha=>normalizar( iv_texto ).
    IF lv_texto IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Codigo, Descricao
      FROM zr_pc_codelist
      WHERE Lista = @iv_lista
      INTO TABLE @DATA(lt_lista).

    LOOP AT lt_lista INTO DATA(ls_lista).
      IF zcl_pc_planilha=>normalizar( ls_lista-Codigo ) = lv_texto
         OR zcl_pc_planilha=>normalizar( ls_lista-Descricao ) = lv_texto.
        rv_codigo = ls_lista-Codigo.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_pc_importacao~opcoes_codelist.
    SELECT Descricao
      FROM zr_pc_codelist
      WHERE Lista = @iv_lista
      ORDER BY Ordem
      INTO TABLE @DATA(lt_lista).

    rv_texto = concat_lines_of( table = VALUE string_table( FOR l IN lt_lista ( CONV string( l-Descricao ) ) )
                                sep   = `, ` ).
  ENDMETHOD.


  METHOD zif_pc_importacao~resumir_erros.
    rt_erros = VALUE #( FOR e IN it_erros FROM 1 TO zif_pc_importacao=>c_max_erros_exibidos ( e ) ).
    DATA(lv_omitidos) = lines( it_erros ) - lines( rt_erros ).
    IF lv_omitidos > 0.
      APPEND |... e mais { lv_omitidos } erro(s) não listado(s).| TO rt_erros.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
