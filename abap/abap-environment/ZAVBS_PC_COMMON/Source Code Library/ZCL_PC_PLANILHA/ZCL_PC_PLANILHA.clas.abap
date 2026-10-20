"! <p class="shorttext synchronized">Pedidos de Compras - Leitura de planilhas (XLSX/CSV)</p>
"! Converte o arquivo enviado pelo usuário em registros indexados pelo nome da
"! coluna, para a importação em massa dos 3 apps (Clientes, Estoque, Pedidos).
"!  - XLSX (assinatura ZIP) é lido pelo XCO, primeira aba, até a coluna T.
"!  - Qualquer outro conteúdo é tratado como CSV (separador , ; ou TAB, UTF-8
"!    com ou sem BOM; se não for UTF-8 válido, assume ISO-8859-1).
"!  - A primeira linha não vazia é o cabeçalho. As colunas são identificadas
"!    pelo nome, sem diferenciar maiúsculas, acentos, espaços ou pontuação.
"!  - Não grava nada: devolve registros e a lista de erros de leitura.
CLASS zcl_pc_planilha DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_max_linhas TYPE i VALUE 500.

    TYPES:
      BEGIN OF ty_coluna,
        campo       TYPE string,
        sinonimos   TYPE string,
        obrigatoria TYPE abap_boolean,
      END OF ty_coluna.
    TYPES tt_colunas TYPE STANDARD TABLE OF ty_coluna WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_valor,
        campo TYPE string,
        valor TYPE string,
      END OF ty_valor.
    TYPES tt_valores TYPE HASHED TABLE OF ty_valor WITH UNIQUE KEY campo.

    TYPES:
      BEGIN OF ty_registro,
        linha   TYPE i,
        valores TYPE tt_valores,
      END OF ty_registro.
    TYPES tt_registros TYPE STANDARD TABLE OF ty_registro WITH EMPTY KEY.

    TYPES tt_matriz TYPE STANDARD TABLE OF string_table WITH EMPTY KEY.

    "! Lê o arquivo e devolve os registros (linhas de dados) já associados às
    "! colunas pedidas. Em ET_ERROS vêm os problemas de leitura/cabeçalho; se
    "! houver algum, ET_REGISTROS fica vazio.
    "! O texto de cada coluna em IT_COLUNAS-CAMPO é o nome de acesso em VALOR( ).
    "! IT_COLUNAS-SINONIMOS: nomes alternativos já normalizados, separados por |.
    CLASS-METHODS ler
      IMPORTING iv_conteudo  TYPE xstring
                it_colunas   TYPE tt_colunas
      EXPORTING et_registros TYPE tt_registros
                et_erros     TYPE string_table.

    "! Valor (aparado) da coluna no registro; vazio se a coluna não existir.
    CLASS-METHODS valor
      IMPORTING is_registro     TYPE ty_registro
                iv_campo        TYPE csequence
      RETURNING VALUE(rv_valor) TYPE string.

    "! Maiúsculas, sem acentos e só A-Z/0-9 (comparação de cabeçalhos).
    CLASS-METHODS normalizar
      IMPORTING iv_texto        TYPE csequence
      RETURNING VALUE(rv_texto) TYPE string.

    "! CSV -> matriz de células (uma linha por linha do arquivo, vazias inclusive).
    CLASS-METHODS ler_csv
      IMPORTING iv_conteudo TYPE xstring
      EXPORTING et_matriz   TYPE tt_matriz
                ev_erro     TYPE string.

    "! Data em ISO (2024-05-31), brasileira (31/05/2024), AAAAMMDD ou número
    "! serial do Excel. Inicial se não for uma data válida.
    CLASS-METHODS para_data
      IMPORTING iv_texto       TYPE csequence
      RETURNING VALUE(rv_data) TYPE d.

    "! Número com ponto ou vírgula decimal, sem separador de milhar
    "! (se houver ponto e vírgula, o último é o decimal).
    CLASS-METHODS para_decimal
      IMPORTING iv_texto  TYPE csequence
      EXPORTING ev_valor  TYPE decfloat34
                ev_valido TYPE abap_boolean.

    "! Número inteiro (aceita 10, 10.0 ou 10,00).
    CLASS-METHODS para_inteiro
      IMPORTING iv_texto  TYPE csequence
      EXPORTING ev_valor  TYPE i
                ev_valido TYPE abap_boolean.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_colunas_xlsx TYPE i VALUE 20.

    TYPES:
      BEGIN OF ty_linha_xlsx,
        c01 TYPE string,
        c02 TYPE string,
        c03 TYPE string,
        c04 TYPE string,
        c05 TYPE string,
        c06 TYPE string,
        c07 TYPE string,
        c08 TYPE string,
        c09 TYPE string,
        c10 TYPE string,
        c11 TYPE string,
        c12 TYPE string,
        c13 TYPE string,
        c14 TYPE string,
        c15 TYPE string,
        c16 TYPE string,
        c17 TYPE string,
        c18 TYPE string,
        c19 TYPE string,
        c20 TYPE string,
      END OF ty_linha_xlsx.
    TYPES tt_linhas_xlsx TYPE STANDARD TABLE OF ty_linha_xlsx WITH EMPTY KEY.

    CLASS-METHODS ler_xlsx
      IMPORTING iv_conteudo TYPE xstring
      EXPORTING et_matriz   TYPE tt_matriz
                ev_erro     TYPE string.

    "! XLSX cujos textos estão em linha na planilha (t="inlineStr"), como gravam
    "! algumas bibliotecas (ex.: openpyxl). O leitor XCO só enxerga textos da
    "! tabela de strings compartilhadas, que é o que Excel, LibreOffice e
    "! Google Planilhas gravam.
    CLASS-METHODS tem_texto_inline
      IMPORTING iv_conteudo      TYPE xstring
      RETURNING VALUE(rv_inline) TYPE abap_boolean.

    CLASS-METHODS decodificar
      IMPORTING iv_conteudo     TYPE xstring
      RETURNING VALUE(rv_texto) TYPE string.

    CLASS-METHODS linha_vazia
      IMPORTING it_celulas      TYPE string_table
      RETURNING VALUE(rv_vazia) TYPE abap_boolean.
ENDCLASS.



CLASS zcl_pc_planilha IMPLEMENTATION.

  METHOD ler.
    CLEAR: et_registros, et_erros.

    IF xstrlen( iv_conteudo ) = 0.
      APPEND `Nenhum arquivo foi enviado.` TO et_erros.
      RETURN.
    ENDIF.

    DATA lt_matriz TYPE tt_matriz.
    DATA lv_erro   TYPE string.

    " Assinatura ZIP (PK) = XLSX; OLE2 = XLS antigo (não suportado); resto = CSV
    IF xstrlen( iv_conteudo ) >= 2 AND iv_conteudo(2) = CONV xstring( '504B' ).
      ler_xlsx( EXPORTING iv_conteudo = iv_conteudo
                IMPORTING et_matriz   = lt_matriz
                          ev_erro     = lv_erro ).
    ELSEIF xstrlen( iv_conteudo ) >= 4 AND iv_conteudo(4) = CONV xstring( 'D0CF11E0' ).
      lv_erro = `Formato .xls não suportado. Salve a planilha como .xlsx ou .csv.`.
    ELSE.
      ler_csv( EXPORTING iv_conteudo = iv_conteudo
               IMPORTING et_matriz   = lt_matriz
                         ev_erro     = lv_erro ).
    ENDIF.

    IF lv_erro IS NOT INITIAL.
      APPEND lv_erro TO et_erros.
      RETURN.
    ENDIF.

    " Cabeçalho = primeira linha não vazia
    DATA(lv_linha_cab) = 0.
    LOOP AT lt_matriz INTO DATA(lt_celulas).
      IF linha_vazia( lt_celulas ) = abap_false.
        lv_linha_cab = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_linha_cab = 0.
      APPEND `A planilha está vazia.` TO et_erros.
      RETURN.
    ENDIF.

    " Coluna (índice) de cada campo pedido
    TYPES:
      BEGIN OF ty_mapa,
        campo  TYPE string,
        indice TYPE i,
      END OF ty_mapa.
    DATA lt_mapa TYPE SORTED TABLE OF ty_mapa WITH UNIQUE KEY campo.

    DATA(lt_cabecalho) = lt_matriz[ lv_linha_cab ].
    LOOP AT lt_cabecalho INTO DATA(lv_titulo).
      DATA(lv_indice) = sy-tabix.
      DATA(lv_norm)   = normalizar( lv_titulo ).
      IF lv_norm IS INITIAL.
        CONTINUE.
      ENDIF.

      LOOP AT it_colunas INTO DATA(ls_coluna).
        IF line_exists( lt_mapa[ campo = ls_coluna-campo ] ).
          CONTINUE.
        ENDIF.
        SPLIT ls_coluna-sinonimos AT '|' INTO TABLE DATA(lt_sinonimos).
        APPEND normalizar( ls_coluna-campo ) TO lt_sinonimos.
        IF line_exists( lt_sinonimos[ table_line = lv_norm ] ).
          INSERT VALUE #( campo = ls_coluna-campo indice = lv_indice ) INTO TABLE lt_mapa.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    LOOP AT it_colunas INTO ls_coluna WHERE obrigatoria = abap_true.
      IF NOT line_exists( lt_mapa[ campo = ls_coluna-campo ] ).
        APPEND |Coluna obrigatória não encontrada no cabeçalho: { ls_coluna-campo }.| TO et_erros.
      ENDIF.
    ENDLOOP.
    IF et_erros IS NOT INITIAL.
      RETURN.
    ENDIF.

    " Linhas de dados (o número da linha é o da planilha, 1 = primeira linha)
    DATA(lv_total) = lines( lt_matriz ).
    DATA(lv_atual) = lv_linha_cab + 1.
    WHILE lv_atual <= lv_total.
      DATA(lt_dados) = lt_matriz[ lv_atual ].
      IF linha_vazia( lt_dados ) = abap_false.
        DATA(ls_registro) = VALUE ty_registro( linha = lv_atual ).
        LOOP AT it_colunas INTO ls_coluna.
          DATA(lv_valor) = VALUE string( ).
          READ TABLE lt_mapa INTO DATA(ls_mapa) WITH TABLE KEY campo = ls_coluna-campo.
          IF sy-subrc = 0 AND ls_mapa-indice <= lines( lt_dados ).
            lv_valor = condense( lt_dados[ ls_mapa-indice ] ).
          ENDIF.
          INSERT VALUE #( campo = ls_coluna-campo valor = lv_valor ) INTO TABLE ls_registro-valores.
        ENDLOOP.
        APPEND ls_registro TO et_registros.
      ENDIF.
      lv_atual = lv_atual + 1.
    ENDWHILE.

    IF et_registros IS INITIAL.
      APPEND `A planilha não possui linhas de dados abaixo do cabeçalho.` TO et_erros.
    ELSEIF lines( et_registros ) > c_max_linhas.
      APPEND |A planilha tem { lines( et_registros ) } linhas de dados; o máximo por importação é { c_max_linhas }.| TO et_erros.
      CLEAR et_registros.
    ENDIF.
  ENDMETHOD.


  METHOD valor.
    READ TABLE is_registro-valores INTO DATA(ls_valor) WITH TABLE KEY campo = iv_campo.
    IF sy-subrc = 0.
      rv_valor = ls_valor-valor.
    ENDIF.
  ENDMETHOD.


  METHOD normalizar.
    DATA(lv_texto) = to_upper( CONV string( iv_texto ) ).
    lv_texto = translate( val  = lv_texto
                          from = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ'
                          to   = 'AAAAAEEEEIIIIOOOOOUUUUC' ).
    rv_texto = replace( val  = lv_texto
                        pcre = `[^A-Z0-9]`
                        with = ``
                        occ  = 0 ).
  ENDMETHOD.


  METHOD linha_vazia.
    rv_vazia = abap_true.
    LOOP AT it_celulas INTO DATA(lv_celula).
      IF condense( lv_celula ) <> ``.
        rv_vazia = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD decodificar.
    DATA(lv_bytes) = iv_conteudo.
    IF xstrlen( lv_bytes ) >= 3 AND lv_bytes(3) = CONV xstring( 'EFBBBF' ).
      lv_bytes = lv_bytes+3.
    ENDIF.

    TRY.
        rv_texto = cl_abap_conv_codepage=>create_in( codepage = 'UTF-8' )->convert( source = lv_bytes ).
      CATCH cx_root.
        " Não é UTF-8 válido (ex.: CSV salvo pelo Excel em ANSI)
        TRY.
            rv_texto = cl_abap_conv_codepage=>create_in( codepage = 'ISO-8859-1' )->convert( source = lv_bytes ).
          CATCH cx_root.
            CLEAR rv_texto.
        ENDTRY.
    ENDTRY.
  ENDMETHOD.


  METHOD ler_csv.
    CLEAR: et_matriz, ev_erro.

    DATA(lv_texto) = decodificar( iv_conteudo ).
    IF lv_texto IS INITIAL.
      ev_erro = `Não foi possível interpretar o arquivo como texto CSV.`.
      RETURN.
    ENDIF.

    lv_texto = replace( val = lv_texto sub = cl_abap_char_utilities=>cr_lf with = cl_abap_char_utilities=>newline occ = 0 ).
    lv_texto = replace( val = lv_texto sub = cl_abap_char_utilities=>cr_lf(1) with = cl_abap_char_utilities=>newline occ = 0 ).

    " Separador: o mais frequente na primeira linha não vazia (; , ou TAB)
    SPLIT lv_texto AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_linhas_txt).
    DATA(lv_primeira) = VALUE string( ).
    LOOP AT lt_linhas_txt INTO DATA(lv_linha_txt).
      IF condense( lv_linha_txt ) <> ``.
        lv_primeira = lv_linha_txt.
        EXIT.
      ENDIF.
    ENDLOOP.
    DATA(lv_qtd_pv)  = count( val = lv_primeira sub = `;` ).
    DATA(lv_qtd_vir) = count( val = lv_primeira sub = `,` ).
    DATA(lv_qtd_tab) = count( val = lv_primeira sub = cl_abap_char_utilities=>horizontal_tab ).
    DATA(lv_sep) = COND string( WHEN lv_qtd_pv >= lv_qtd_vir AND lv_qtd_pv >= lv_qtd_tab AND lv_qtd_pv > 0 THEN `;`
                                WHEN lv_qtd_tab > lv_qtd_vir THEN cl_abap_char_utilities=>horizontal_tab
                                ELSE `,` ).

    DATA lt_linha  TYPE string_table.
    DATA lv_campo  TYPE string.
    DATA lv_aspas  TYPE abap_boolean.
    DATA lv_pos    TYPE i.
    DATA(lv_tam)   = strlen( lv_texto ).

    WHILE lv_pos < lv_tam.
      DATA(lv_c) = substring( val = lv_texto off = lv_pos len = 1 ).

      IF lv_aspas = abap_true.
        IF lv_c = `"`.
          IF lv_pos + 1 < lv_tam AND substring( val = lv_texto off = lv_pos + 1 len = 1 ) = `"`.
            lv_campo = lv_campo && `"`.
            lv_pos = lv_pos + 1.
          ELSE.
            lv_aspas = abap_false.
          ENDIF.
        ELSE.
          lv_campo = lv_campo && lv_c.
        ENDIF.
      ELSEIF lv_c = `"`.
        lv_aspas = abap_true.
      ELSEIF lv_c = lv_sep.
        APPEND lv_campo TO lt_linha.
        CLEAR lv_campo.
      ELSEIF lv_c = cl_abap_char_utilities=>newline.
        APPEND lv_campo TO lt_linha.
        APPEND lt_linha TO et_matriz.
        CLEAR: lv_campo, lt_linha.
      ELSE.
        lv_campo = lv_campo && lv_c.
      ENDIF.

      lv_pos = lv_pos + 1.
    ENDWHILE.

    " Última linha sem quebra final
    IF lv_campo IS NOT INITIAL OR lt_linha IS NOT INITIAL.
      APPEND lv_campo TO lt_linha.
      APPEND lt_linha TO et_matriz.
    ENDIF.
  ENDMETHOD.


  METHOD tem_texto_inline.
    rv_inline = abap_false.
    TRY.
        DATA(lo_zip) = NEW cl_abap_zip( ).
        lo_zip->load( zip = iv_conteudo ).
        lo_zip->get( EXPORTING  name    = `xl/worksheets/sheet1.xml`
                     IMPORTING  content = DATA(lv_xml)
                     EXCEPTIONS OTHERS  = 1 ).
        IF sy-subrc = 0.
          DATA(lv_texto) = cl_abap_conv_codepage=>create_in( )->convert( source = lv_xml ).
          rv_inline = xsdbool( lv_texto CS `t="inlineStr"` ).
        ENDIF.
      CATCH cx_root.
        rv_inline = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD ler_xlsx.
    CLEAR: et_matriz, ev_erro.

    DATA lt_linhas TYPE tt_linhas_xlsx.

    IF tem_texto_inline( iv_conteudo ) = abap_true.
      ev_erro = `Este XLSX guarda os textos em formato "inline" (gerado por biblioteca, não pelo Excel) e não pode ser lido. Abra no Excel e salve de novo como .xlsx, ou envie como .csv.`.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_planilha) = xco_cp_xlsx=>document->for_file_content( iv_conteudo
                              )->read_access(
                              )->get_workbook(
                              )->worksheet->at_position( 1 ).

        DATA(lo_padrao) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
                            )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
                            )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'T' )
                            )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
                            )->get_pattern( ).

        lo_planilha->select( lo_padrao
          )->row_stream(
          )->operation->write_to( REF #( lt_linhas )
          )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->execute( ).
      CATCH cx_root INTO DATA(lx_xlsx).
        ev_erro = |Não foi possível ler a planilha XLSX ({ lx_xlsx->get_text( ) }). | &&
                  |Se ela foi salva fora do Excel (ex.: LibreOffice), salve como .csv e envie de novo.|.
        RETURN.
    ENDTRY.

    FIELD-SYMBOLS <lv_celula> TYPE string.
    LOOP AT lt_linhas INTO DATA(ls_linha).
      DATA lt_celulas TYPE string_table.
      CLEAR lt_celulas.
      DO c_colunas_xlsx TIMES.
        ASSIGN COMPONENT sy-index OF STRUCTURE ls_linha TO <lv_celula>.
        APPEND <lv_celula> TO lt_celulas.
      ENDDO.
      APPEND lt_celulas TO et_matriz.
    ENDLOOP.
  ENDMETHOD.


  METHOD para_data.
    DATA lv_ano TYPE i.
    DATA lv_mes TYPE i.
    DATA lv_dia TYPE i.

    DATA(lv_texto) = condense( CONV string( iv_texto ) ).
    IF lv_texto IS INITIAL.
      RETURN.
    ENDIF.

    FIND PCRE `^(\d{4})-(\d{1,2})-(\d{1,2})` IN lv_texto SUBMATCHES DATA(lv_s1) DATA(lv_s2) DATA(lv_s3).
    IF sy-subrc = 0.
      lv_ano = lv_s1.
      lv_mes = lv_s2.
      lv_dia = lv_s3.
    ELSEIF matches( val = lv_texto pcre = `\d{1,2}[/.-]\d{1,2}[/.-]\d{4}` ).
      FIND PCRE `^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$` IN lv_texto SUBMATCHES lv_s3 lv_s2 lv_s1.
      lv_ano = lv_s1.
      lv_mes = lv_s2.
      lv_dia = lv_s3.
    ELSEIF matches( val = lv_texto pcre = `\d{8}` ).
      lv_ano = CONV i( lv_texto(4) ).
      lv_mes = CONV i( lv_texto+4(2) ).
      lv_dia = CONV i( lv_texto+6(2) ).
    ELSEIF matches( val = lv_texto pcre = `\d{4,6}(\.0+)?` ).
      " Número serial do Excel (dias desde 30/12/1899)
      DATA(lv_serial) = CONV i( match( val = lv_texto pcre = `^\d+` ) ).
      DATA(lv_base)   = CONV d( '18991230' ).
      rv_data = lv_base + lv_serial.
      RETURN.
    ELSE.
      RETURN.
    ENDIF.

    IF lv_ano < 1900 OR lv_mes < 1 OR lv_mes > 12 OR lv_dia < 1 OR lv_dia > 31.
      RETURN.
    ENDIF.

    " Dia inexistente no mês (ex.: 31/02) vira outro mês na soma de dias
    DATA(lv_primeiro) = CONV d( |{ lv_ano WIDTH = 4 ALIGN = RIGHT PAD = '0' }| &&
                                |{ lv_mes WIDTH = 2 ALIGN = RIGHT PAD = '0' }01| ).
    DATA(lv_calculada) = CONV d( lv_primeiro + ( lv_dia - 1 ) ).
    IF lv_calculada+4(2) = lv_primeiro+4(2).
      rv_data = lv_calculada.
    ENDIF.
  ENDMETHOD.


  METHOD para_decimal.
    CLEAR: ev_valor, ev_valido.

    DATA(lv_texto) = condense( CONV string( iv_texto ) ).
    lv_texto = replace( val = lv_texto pcre = `^R\$\s*` with = `` ).
    lv_texto = replace( val = lv_texto pcre = `\s` with = `` occ = 0 ).
    IF lv_texto IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_ultimo_ponto)   = find( val = lv_texto sub = `.` occ = -1 ).
    DATA(lv_ultima_virgula) = find( val = lv_texto sub = `,` occ = -1 ).

    IF lv_ultimo_ponto >= 0 AND lv_ultima_virgula >= 0.
      " Os dois presentes: o último é o separador decimal, o outro é milhar
      IF lv_ultima_virgula > lv_ultimo_ponto.
        lv_texto = replace( val = lv_texto sub = `.` with = `` occ = 0 ).
        lv_texto = replace( val = lv_texto sub = `,` with = `.` ).
      ELSE.
        lv_texto = replace( val = lv_texto sub = `,` with = `` occ = 0 ).
      ENDIF.
    ELSEIF lv_ultima_virgula >= 0.
      lv_texto = replace( val = lv_texto sub = `,` with = `.` occ = 0 ).
    ENDIF.

    IF NOT matches( val = lv_texto pcre = `-?\d+(\.\d+)?([eE][+-]?\d+)?` ).
      RETURN.
    ENDIF.

    TRY.
        ev_valor  = CONV decfloat34( lv_texto ).
        ev_valido = abap_true.
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
        ev_valido = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD para_inteiro.
    CLEAR: ev_valor, ev_valido.

    para_decimal( EXPORTING iv_texto  = iv_texto
                  IMPORTING ev_valor  = DATA(lv_decimal)
                            ev_valido = DATA(lv_ok) ).
    IF lv_ok = abap_false.
      RETURN.
    ENDIF.
    IF frac( lv_decimal ) <> 0 OR abs( lv_decimal ) > 2000000000.
      RETURN.
    ENDIF.

    ev_valor  = CONV i( lv_decimal ).
    ev_valido = abap_true.
  ENDMETHOD.

ENDCLASS.
