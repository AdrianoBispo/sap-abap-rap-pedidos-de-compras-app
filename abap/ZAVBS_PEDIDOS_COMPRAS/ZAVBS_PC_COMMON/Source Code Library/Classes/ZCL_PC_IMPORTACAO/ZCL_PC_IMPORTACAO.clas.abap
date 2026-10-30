"! Classe de apoio para a implementação de  metodos comuns às actions ImportarPlanilha dos BOs Cliente, Item e Pedido:
"!
"! <ul>
"!  <li>Normalização de campos que o Excel costuma estragar (zeros à esquerda);</li>
"!  <li>Conversão de texto para código de CodeList</li>
"!  <li>resumo da lista de erros.</li>
"! </ul>
"!
"! Constantes, tipos e métodos públicos são declarados na interface <strong> {@link ZIF_PC_IMPORTACAO} </strong>.
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

  PRIVATE SECTION.
    TYPES:
      "! Entrada de CodeList (ZR_PC_CODELIST) guardada no buffer da classe
      BEGIN OF ty_codelist,
        lista     TYPE zr_pc_codelist-Lista,
        codigo    TYPE zr_pc_codelist-Codigo,
        descricao TYPE zr_pc_codelist-Descricao,
        ordem     TYPE zr_pc_codelist-Ordem,
      END OF ty_codelist,
      "! Entradas de CodeList ordenadas por lista e ordem de exibição
      tt_codelist TYPE SORTED TABLE OF ty_codelist WITH NON-UNIQUE KEY lista ordem.

    "! Buffer das CodeLists já lidas nesta sessão: a importação chama
    "! {@link .METH:converter_codelist} uma vez por linha da planilha
    CLASS-DATA gt_codelist TYPE tt_codelist.
    "! Listas já carregadas em {@link .DATA:gt_codelist} (inclusive as vazias)
    CLASS-DATA gt_listas_lidas TYPE SORTED TABLE OF zr_pc_codelist-Lista WITH UNIQUE KEY table_line.

    "! Entradas de uma CodeList, lidas do banco só na primeira chamada por lista.
    "! @parameter iv_lista | Nome da lista (ex.: GENERO, CATEGORIA)
    "! @parameter rt_itens | Entradas da lista, na ordem de exibição
    CLASS-METHODS itens_codelist
      IMPORTING iv_lista        TYPE csequence
      RETURNING VALUE(rt_itens) TYPE tt_codelist.

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

    " Entradas da lista vêm do buffer: sem consulta ao banco a cada linha
    LOOP AT itens_codelist( iv_lista ) INTO DATA(ls_lista).

      IF zcl_pc_planilha=>normalizar( ls_lista-codigo ) = lv_texto
         OR zcl_pc_planilha=>normalizar( ls_lista-descricao ) = lv_texto.
        rv_codigo = ls_lista-codigo.
        RETURN.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.


  METHOD zif_pc_importacao~opcoes_codelist.

    rv_texto = concat_lines_of( table = VALUE string_table( FOR l IN itens_codelist( iv_lista )
                                                            ( CONV string( l-descricao ) ) )
                                sep   = `, ` ).
  ENDMETHOD.


  METHOD itens_codelist.

    " 1) Primeira chamada para a lista: uma única leitura, guardada no buffer
    IF NOT line_exists( gt_listas_lidas[ table_line = iv_lista ] ).
      SELECT Lista AS lista, Codigo AS codigo, Descricao AS descricao, Ordem AS ordem
        FROM zr_pc_codelist
        WHERE Lista = @iv_lista
        APPENDING CORRESPONDING FIELDS OF TABLE @gt_codelist.
      INSERT CONV #( iv_lista ) INTO TABLE gt_listas_lidas.
    ENDIF.

    " 2) Entradas da lista a partir do buffer, já na ordem de exibição
    rt_itens = VALUE #( FOR c IN gt_codelist WHERE ( lista = iv_lista ) ( c ) ).
  ENDMETHOD.


  METHOD zif_pc_importacao~resumir_erros.

    rt_erros = VALUE #( FOR e IN it_erros FROM 1 TO zif_pc_importacao=>c_max_erros_exibidos ( e ) ).

    DATA(lv_omitidos) = lines( it_erros ) - lines( rt_erros ).

    IF lv_omitidos > 0.
      APPEND |... e mais { lv_omitidos } erro(s) não listado(s).| TO rt_erros.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
