"! <p class="shorttext synchronized">Pedidos de Compras - Apoio à importação de planilhas</p>
"! Rotinas comuns às actions ImportarPlanilha dos BOs Cliente, Item e Pedido:
"! normalização de campos que o Excel costuma estragar (zeros à esquerda),
"! conversão de texto para código de CodeList e resumo da lista de erros.
CLASS zcl_pc_importacao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_max_erros_exibidos TYPE i VALUE 15.

    "! Somente dígitos, completando com zeros à esquerda até 11 (o Excel
    "! guarda CPF como número e perde os zeros iniciais).
    CLASS-METHODS normalizar_cpf
      IMPORTING iv_texto      TYPE csequence
      RETURNING VALUE(rv_cpf) TYPE string.

    "! Somente dígitos, completando com zeros à esquerda até 8.
    CLASS-METHODS normalizar_cep
      IMPORTING iv_texto      TYPE csequence
      RETURNING VALUE(rv_cep) TYPE string.

    "! Código da CodeList cujo código OU descrição (sem acento/caixa) bate com
    "! o texto. Vazio se o texto estiver vazio ou não existir na lista.
    CLASS-METHODS converter_codelist
      IMPORTING iv_lista         TYPE csequence
                iv_texto         TYPE csequence
      RETURNING VALUE(rv_codigo) TYPE string.

    "! Descrições da CodeList, para citar as opções válidas numa mensagem.
    CLASS-METHODS opcoes_codelist
      IMPORTING iv_lista        TYPE csequence
      RETURNING VALUE(rv_texto) TYPE string.

    "! Limita a lista a C_MAX_ERROS_EXIBIDOS itens e acrescenta o total omitido.
    CLASS-METHODS resumir_erros
      IMPORTING it_erros        TYPE string_table
      RETURNING VALUE(rt_erros) TYPE string_table.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_pc_importacao IMPLEMENTATION.

  METHOD normalizar_cpf.
    rv_cpf = zcl_pc_util=>somente_digitos( iv_texto ).
    IF rv_cpf IS NOT INITIAL AND strlen( rv_cpf ) < 11.
      rv_cpf = |{ rv_cpf WIDTH = 11 ALIGN = RIGHT PAD = '0' }|.
    ENDIF.
  ENDMETHOD.


  METHOD normalizar_cep.
    rv_cep = zcl_pc_util=>somente_digitos( iv_texto ).
    IF rv_cep IS NOT INITIAL AND strlen( rv_cep ) < 8.
      rv_cep = |{ rv_cep WIDTH = 8 ALIGN = RIGHT PAD = '0' }|.
    ENDIF.
  ENDMETHOD.


  METHOD converter_codelist.
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


  METHOD opcoes_codelist.
    SELECT Descricao
      FROM zr_pc_codelist
      WHERE Lista = @iv_lista
      ORDER BY Ordem
      INTO TABLE @DATA(lt_lista).

    rv_texto = concat_lines_of( table = VALUE string_table( FOR l IN lt_lista ( CONV string( l-Descricao ) ) )
                                sep   = `, ` ).
  ENDMETHOD.


  METHOD resumir_erros.
    rt_erros = VALUE #( FOR e IN it_erros FROM 1 TO c_max_erros_exibidos ( e ) ).
    DATA(lv_omitidos) = lines( it_erros ) - lines( rt_erros ).
    IF lv_omitidos > 0.
      APPEND |... e mais { lv_omitidos } erro(s) não listado(s).| TO rt_erros.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
