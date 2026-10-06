CLASS ltcl_planilha DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS xstr
      IMPORTING iv_texto       TYPE string
      RETURNING VALUE(rv_hex)  TYPE xstring.
    METHODS colunas
      RETURNING VALUE(rt_colunas) TYPE zcl_pc_planilha=>tt_colunas.

    METHODS normaliza_cabecalho   FOR TESTING.
    METHODS csv_ponto_e_virgula   FOR TESTING.
    METHODS csv_virgula_aspas     FOR TESTING.
    METHODS csv_com_bom_e_crlf    FOR TESTING.
    METHODS csv_ansi_iso8859      FOR TESTING.
    METHODS cabecalho_sinonimo    FOR TESTING.
    METHODS coluna_obrigatoria    FOR TESTING.
    METHODS planilha_vazia        FOR TESTING.
    METHODS numero_linha_real     FOR TESTING.
    METHODS xls_antigo_rejeitado  FOR TESTING.
    METHODS limite_de_linhas      FOR TESTING.
    METHODS xlsx_ida_e_volta      FOR TESTING.
    METHODS xlsx_texto_inline     FOR TESTING.
    METHODS xlsx_libreoffice_nao_lido FOR TESTING.
    METHODS xlsx_de_xlsxwriter    FOR TESTING.
    METHODS datas                 FOR TESTING.
    METHODS decimais_e_inteiros   FOR TESTING.
ENDCLASS.


CLASS ltcl_planilha IMPLEMENTATION.

  METHOD xstr.
    rv_hex = cl_abap_conv_codepage=>create_out( codepage = 'UTF-8' )->convert( source = iv_texto ).
  ENDMETHOD.

  METHOD colunas.
    rt_colunas = VALUE #(
      ( campo = `CPF`  obrigatoria = abap_true )
      ( campo = `Nome` obrigatoria = abap_true )
      ( campo = `E-mail` sinonimos = `EMAILCLIENTE` obrigatoria = abap_true )
      ( campo = `Complemento` ) ).
  ENDMETHOD.

  METHOD normaliza_cabecalho.
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>normalizar( ` Data de Nascimento ` )
                                        exp = `DATADENASCIMENTO` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>normalizar( `Gênero` ) exp = `GENERO` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>normalizar( `E-mail` ) exp = `EMAIL` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>normalizar( `Preço unitário (R$)` )
                                        exp = `PRECOUNITARIOR` ).
  ENDMETHOD.

  METHOD csv_ponto_e_virgula.
    DATA(lv_csv) = |CPF;Nome;E-mail\n52998224725;Maria Souza;maria@x.com\n39053344772;João Lima;joao@x.com\n|.
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = xstr( lv_csv )
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_erros ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_reg ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `CPF` )
                                        exp = `52998224725` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 2 ] iv_campo = `Nome` )
                                        exp = `João Lima` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 2 ] iv_campo = `E-mail` )
                                        exp = `joao@x.com` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 2 ] iv_campo = `Complemento` )
                                        exp = `` ).
  ENDMETHOD.

  METHOD csv_virgula_aspas.
    " Campo entre aspas com vírgula, aspas escapadas e quebra de linha interna
    DATA(lv_csv) = |CPF,Nome,E-mail\n1,"Silva, Maria ""Mara""",m@x.com\n2,"Linha1\nLinha2",n@x.com|.
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = xstr( lv_csv )
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_erros ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_reg ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `Nome` )
                                        exp = `Silva, Maria "Mara"` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 2 ] iv_campo = `E-mail` )
                                        exp = `n@x.com` ).
  ENDMETHOD.

  METHOD csv_com_bom_e_crlf.
    DATA(lv_bom) = CONV xstring( 'EFBBBF' ).
    DATA(lv_csv) = |CPF;Nome;E-mail\r\n1;Ana;a@x.com\r\n|.
    DATA(lv_corpo)    = xstr( lv_csv ).
    DATA lv_conteudo TYPE xstring.
    CONCATENATE lv_bom lv_corpo INTO lv_conteudo IN BYTE MODE.
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = lv_conteudo
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_erros ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_reg ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `Nome` )
                                        exp = `Ana` ).
  ENDMETHOD.

  METHOD csv_ansi_iso8859.
    " "João" em ISO-8859-1 (Excel em português salva CSV assim)
    DATA(lv_ansi) = cl_abap_conv_codepage=>create_out( codepage = 'ISO-8859-1' )->convert(
                      source = |CPF;Nome;E-mail\n1;João;a@x.com| ).
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = lv_ansi
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_erros ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `Nome` )
                                        exp = `João` ).
  ENDMETHOD.

  METHOD cabecalho_sinonimo.
    " Ordem diferente, caixa/acentos/pontuação diferentes e coluna extra ignorada
    DATA(lv_csv) = |extra;EMAIL CLIENTE;  nome ;cpf\nx;a@x.com;Ana;123\n|.
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = xstr( lv_csv )
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_erros ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `E-mail` )
                                        exp = `a@x.com` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `CPF` )
                                        exp = `123` ).
  ENDMETHOD.

  METHOD coluna_obrigatoria.
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = xstr( |CPF;Nome\n1;Ana\n| )
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_reg ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_erros ) exp = 1 ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lt_erros[ 1 ] CS `E-mail` ) ).
  ENDMETHOD.

  METHOD planilha_vazia.
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = xstr( `CPF;Nome;E-mail` )
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_reg ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_erros ) exp = 1 ).

    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = xstr( |\n\n| )
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = lt_reg
                                    et_erros     = lt_erros ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_erros ) exp = 1 ).
  ENDMETHOD.

  METHOD numero_linha_real.
    " Linhas vazias no meio e no começo não deslocam o número informado
    DATA(lv_csv) = |\nCPF;Nome;E-mail\n1;Ana;a@x.com\n\n;;\n2;Bia;b@x.com\n|.
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = xstr( lv_csv )
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_erros ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_reg ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_reg[ 1 ]-linha exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_reg[ 2 ]-linha exp = 6 ).
  ENDMETHOD.

  METHOD xls_antigo_rejeitado.
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = CONV xstring( 'D0CF11E0A1B11AE1' )
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_reg ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lt_erros[ 1 ] CS `.xls` ) ).
  ENDMETHOD.

  METHOD limite_de_linhas.
    DATA(lv_csv) = |CPF;Nome;E-mail\n|.
    DO zcl_pc_planilha=>c_max_linhas + 1 TIMES.
      lv_csv = lv_csv && |{ sy-index };N;e@x.com\n|.
    ENDDO.
    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = xstr( lv_csv )
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_reg ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_erros ) exp = 1 ).
  ENDMETHOD.

  METHOD xlsx_ida_e_volta.
    " Gera um XLSX real com o XCO e lê de volta pelo parser
    TYPES:
      BEGIN OF ty_linha,
        a TYPE string,
        b TYPE string,
        c TYPE string,
      END OF ty_linha.
    DATA lt_linhas TYPE STANDARD TABLE OF ty_linha WITH EMPTY KEY.
    lt_linhas = VALUE #( ( a = `CPF`         b = `Nome`       c = `E-mail` )
                         ( a = `52998224725` b = `Maria Ação` c = `m@x.com` )
                         ( a = `39053344772` b = `João`       c = `j@x.com` ) ).

    DATA(lo_escrita) = xco_cp_xlsx=>document->empty( )->write_access( ).
    DATA(lo_planilha) = lo_escrita->get_workbook( )->worksheet->at_position( 1 ).
    DATA(lo_padrao) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
                        )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
                        )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'C' )
                        )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
                        )->get_pattern( ).
    lo_planilha->select( lo_padrao )->row_stream( )->operation->write_from( REF #( lt_linhas ) )->execute( ).
    DATA(lv_xlsx) = lo_escrita->get_file_content( ).

    zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = lv_xlsx
                                    it_colunas   = colunas( )
                          IMPORTING et_registros = DATA(lt_reg)
                                    et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_erros ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_reg ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `Nome` )
                                        exp = `Maria Ação` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 2 ] iv_campo = `CPF` )
                                        exp = `39053344772` ).
    cl_abap_unit_assert=>assert_equals( act = lt_reg[ 2 ]-linha exp = 3 ).
  ENDMETHOD.

  METHOD xlsx_texto_inline.
    " XLSX gerado pelo openpyxl (textos em linha, sem sharedStrings.xml)
    DATA lv_b64 TYPE string.
    lv_b64 = lv_b64 && `UEsDBBQAAAAIAHa/RV1Gx01IlQAAAM0AAAAQAAAAZG9jUHJvcHMvYXBwLnhtbE3PTQvCMAwG4L9SdreZih6kDkQ9ip68zy51hbYpbYT67+0EP255ecgboi6JIia2mEXxLuRtMzLHDUDWI/o+y8qhiqHke64x3YGMsRoPpB8eA8OibdeAhTEMOMzit7Dp1C5GZ3XPlkJ3`.
    lv_b64 = lv_b64 && `sjpRJsPiWDQ6sScfq9wcChDneiU+ixNLOZcrBf+LU8sVU57mym/8ZAW/B7oXUEsDBBQAAAAIAHa/RV09gFuB6wAAAMsBAAARAAAAZG9jUHJvcHMvY29yZS54bWylkcFOwzAMhl9l6r112o1KRF0uoJ2GhMQkELfI8bZoTRslRu3enrZsHQhuHOP/82dbqdBLbAM9h9ZT`.
    lv_b64 = lv_b64 && `YEtx0bu6iRL9OjkyewkQ8UhOx2wgmiHct8FpHp7hAF7jSR8ICiFKcMTaaNYwClM/G5OL0uCs9B+hngQGgWpy1HCEPMvhxjIFF/9smJKZ7KOdqa7rsm45ccNGObw9bV+m5VPbRNYNUqIqgxIDaW6DGi/y576u4Fuxusz+KpBZDBMknz2tk2vyunx43G0SVYiiTHORinIn`.
    lv_b64 = lv_b64 && `Cnl3L1er99H1o/8mdK2xe/sP41WgKvj1b+oTUEsDBBQAAAAIAHa/RV2ZXJwjEAYAAJwnAAATAAAAeGwvdGhlbWUvdGhlbWUxLnhtbO1aW3PaOBR+76/QeGf2bQvGNoG2tBNzaXbbtJmE7U4fhRFYjWx5ZJGEf79HNhDLlg3tkk26mzwELOn7zkVH5+g4efPuLmLohoiU`.
    lv_b64 = lv_b64 && `8nhg2S/b1ru3L97gVzIkEUEwGaev8MAKpUxetVppAMM4fckTEsPcgosIS3gUy9Zc4FsaLyPW6rTb3VaEaWyhGEdkYH1eLGhA0FRRWm9fILTlHzP4FctUjWWjARNXQSa5iLTy+WzF/NrePmXP6TodMoFuMBtYIH/Ob6fkTlqI4VTCxMBqZz9Wa8fR0kiAgsl9lAW6Sfaj`.
    lv_b64 = lv_b64 && `0xUIMg07Op1YznZ89sTtn4zK2nQ0bRrg4/F4OLbL0otwHATgUbuewp30bL+kQQm0o2nQZNj22q6RpqqNU0/T933f65tonAqNW0/Ta3fd046Jxq3QeA2+8U+Hw66JxqvQdOtpJif9rmuk6RZoQkbj63oSFbXlQNMgAFhwdtbM0gOWXin6dZQa2R273UFc8FjuOYkR/sbF`.
    lv_b64 = lv_b64 && `BNZp0hmWNEZynZAFDgA3xNFMUHyvQbaK4MKS0lyQ1s8ptVAaCJrIgfVHgiHF3K/99Ze7yaQzep19Os5rlH9pqwGn7bubz5P8c+jkn6eT101CznC8LAnx+yNbYYcnbjsTcjocZ0J8z/b2kaUlMs/v+QrrTjxnH1aWsF3Pz+SejHIju932WH32T0duI9epwLMi15RGJEWf`.
    lv_b64 = lv_b64 && `yC265BE4tUkNMhM/CJ2GmGpQHAKkCTGWoYb4tMasEeATfbe+CMjfjYj3q2+aPVehWEnahPgQRhrinHPmc9Fs+welRtH2Vbzco5dYFQGXGN80qjUsxdZ4lcDxrZw8HRMSzZQLBkGGlyQmEqk5fk1IE/4rpdr+nNNA8JQvJPpKkY9psyOndCbN6DMawUavG3WHaNI8ev4F`.
    lv_b64 = lv_b64 && `+Zw1ChyRGx0CZxuzRiGEabvwHq8kjpqtwhErQj5iGTYacrUWgbZxqYRgWhLG0XhO0rQR/FmsNZM+YMjszZF1ztaRDhGSXjdCPmLOi5ARvx6GOEqa7aJxWAT9nl7DScHogstm/bh+htUzbCyO90fUF0rkDyanP+kyNAejmlkJvYRWap+qhzQ+qB4yCgXxuR4+5Xp4CjeW`.
    lv_b64 = lv_b64 && `xrxQroJ7Af/R2jfCq/iCwDl/Ln3Ppe+59D2h0rc3I31nwdOLW95GblvE+64x2tc0LihjV3LNyMdUr5Mp2DmfwOz9aD6e8e362SSEr5pZLSMWkEuBs0EkuPyLyvAqxAnoZFslCctU02U3ihKeQhtu6VP1SpXX5a+5KLg8W+Tpr6F0PizP+Txf57TNCzNDt3JL6raUvrUm`.
    lv_b64 = lv_b64 && `OEr0scxwTh7LDDtnPJIdtnegHTX79l125COlMFOXQ7gaQr4Dbbqd3Do4npiRuQrTUpBvw/npxXga4jnZBLl9mFdt59jR0fvnwVGwo+88lh3HiPKiIe6hhpjPw0OHeXtfmGeVxlA0FG1srCQsRrdguNfxLBTgZGAtoAeDr1EC8lJVYDFbxgMrkKJ8TIxF6HDnl1xf49GS`.
    lv_b64 = lv_b64 && `49umZbVuryl3GW0iUjnCaZgTZ6vK3mWxwVUdz1Vb8rC+aj20FU7P/lmtyJ8MEU4WCxJIY5QXpkqi8xlTvucrScRVOL9FM7YSlxi84+bHcU5TuBJ2tg8CMrm7Oal6ZTFnpvLfLQwJLFuIWRLiTV3t1eebnK56Inb6l3fBYPL9cMlHD+U751/0XUOufvbd4/pukztITJx5`.
    lv_b64 = lv_b64 && `xREBdEUCI5UcBhYXMuRQ7pKQBhMBzZTJRPACgmSmHICY+gu98gy5KRXOrT45f0Usg4ZOXtIlEhSKsAwFIRdy4+/vk2p3jNf6LIFthFQyZNUXykOJwT0zckPYVCXzrtomC4Xb4lTNuxq+JmBLw3punS0n/9te1D20Fz1G86OZ4B6zh3OberjCRaz/WNYe+TLfOXDbOt4D`.
    lv_b64 = lv_b64 && `XuYTLEOkfsF9ioqAEativrqvT/klnDu0e/GBIJv81tuk9t3gDHzUq1qlZCsRP0sHfB+SBmOMW/Q0X48UYq2msa3G2jEMeYBY8wyhZjjfh0WaGjPVi6w5jQpvQdVA5T/b1A1o9g00HJEFXjGZtjaj5E4KPNz+7w2wwsSO4e2LvwFQSwMEFAAAAAgAdr9FXefJcxzqAQAA`.
    lv_b64 = lv_b64 && `iwQAABgAAAB4bC93b3Jrc2hlZXRzL3NoZWV0MS54bWx1VFGOmzAQvQriADExSYAVIO0mWbWVWqW7avvtwBCsxZjaTtKepx97kFxsbSfLOinww4z93sx7o4H0yMWLrAGU94c1rcz8WqnuDiFZ1MCInPAOWn1TccGI0qnYIdkJIKUlsQbhIFggRmjr56k924g85XvV0BY2`.
    lv_b64 = lv_b64 && `wpN7xoj4+wANP2b+1H8/eKK7WtkDlKcd2cEzqB+dJugU9XVKyqCVlLeegCrz76d369AyLOInhaN0Ys+Y2XL+YpLPZeYHRhM0UChTgujXAZbQNKaSVvL7UtT/aGqYbvxe/tH61/K2RMKSN79oqerMj32vhIrsG/XEj5/g4mn+IXFFFMlTwY+eMGbztDCBaamBtDVDelZC`.
    lv_b64 = lv_b64 && `n1PdSeXLzWOKlBZgUlRc4A9j8G+cwQB+OYonsjATVXyAtRpjbQScXocY6zHG9z1pFS1JeaMO6UH008D9NLAtYxbokE9xOJsvojgJUnRwZ4BHen3hp3/cK4l3f3rV0dA4NFXaVeu7hDiJ4usGqysVsySZJNeAtQvA8/7yylTYmwod9BwnSYzxLHJoZ1fhiKuvRFAy5CX8`.
    lv_b64 = lv_b64 && `30uE8eLGi9s81k4C55ne2HKx4Y0r5Cyx+Ui1rB1tpddApTnBJNKrLs5bf04U76y6LVeKMxvW+mcBwgD0fcW56hPz1fX/n/wNUEsDBBQAAAAIAHa/RV3XYS8ZdQIAAOEKAAANAAAAeGwvc3R5bGVzLnhtbN1WS4+bMBD+K4j7lk1oUaiAQ5EiVWqrlXYPvZrYJJb8oMas`.
    lv_b64 = lv_b64 && `kv76erCXwG6GqlVPBUWemc/fvDwWKXp7EezxxJiNzlKovoxP1nYfk6Q/nJgk/TvdMeWQVhtJrFPNMek7wwjtgSRFsr2/zxJJuIqrQg1yL20fHfSgbBlvJlPkl8/UGbP3ceTd1ZqyMr64507KO0rjKKmKJDipilarpS8wOI9EsuiZiDKuieCN4SOtJZKLi7dvR8tBC20i`.
    lv_b64 = lv_b64 && `68pgQAdT/9Nv2AQVagy+JFfa+AR8mHGBLLgQUxbb2BuqoiPWMqP2TvGk0foWC/LTpXNZHA25bLYf4hljXFyYRhvKzKJcb6oKwVoLDMOPp1GwuoOl0dZqCRLl5KgV8Zm80ILgfB+YEI9w0N/bRYBzOzuXezgVNYkuqyB6N0GBAHN33vnM7/bv/Hb8WdtPgytIjfqPQVv2`.
    lv_b64 = lv_b64 && `YFjLz6N+bq8JLNyHcfqnAZJQ06xzi75N1ghmsYy/wTSLmY9m4MJyFbQTp5Spt+1z/i1p3PVbBHC7KGvJIOzTBJbxVf7KKB9kPu16gMLCrqv8BWZlk10vggvGFWVnRuugmmMzipETXNjwjIzX0H58EAhleRCBAERjoWmgLM9DY/2Pde3wujyIZri7De1w1g5ned5NqB5f`.
    lv_b64 = lv_b64 && `NBbCyt2DlJznaZplaHvr+nYaNdrDLIMf4hDNEDhoLIj2p51fGYCVsfnNbKCnvDo2aMkrI4qWvNJ5gJAeAifPkQFAYwEHPRR0oiAJJBaMGsJKUzhnNEP0mq9AeY5CMKTI9GYZ1qgMXuS80EuUpnmOQAAiaaQpCsGFXYHQNCARFEpT/yF99T1LXr5zyfVPbfULUEsDBBQA`.
    lv_b64 = lv_b64 && `AAAIAHa/RV23R+uKwAAAABYCAAALAAAAX3JlbHMvLnJlbHOdkktuAjEMQK8SZV9MqcQCMazYsEOIC7iJ56OZxJFjxPT2jdjAIGgRS/+eni2vDzSgdhxz26VsxjDEXNlWNa0AsmspYJ5xolgqNUtALaE0kND12BAs5vMlyC3Dbta3THP8SfQKkeu6c7RldwoU9QH4rsOa`.
    lv_b64 = lv_b64 && `I0pDWtlxgDNL/83czwrUmp2vrOz8pzXwpszz9SCQokdFcCz0kaRMi3aUrz6e3b6k86VjYrR43+j/89CoFD35v50wpYnS10UJJm+w+QVQSwMEFAAAAAgAdr9FXeSwa+4wAQAAKAIAAA8AAAB4bC93b3JrYm9vay54bWyNkNFOwzAMRX+lygfQboJJTOtemIBJCBBDe89a`.
    lv_b64 = lv_b64 && `d7WWxJXjbrCvJ0kpTOKFJ8fX1sm9XpyIDzuiQ/ZhjfNzLlUr0s3z3FctWO2vqAMXZg2x1RJa3ufUNFjBiqregpN8WhSznMFoQXK+xc6rgfYflu8YdO1bALFmQFmNTi0Xo7NXzvLLjgSq+FNUo7JFOPnfhdhmR/S4Q4PyWar0NqAyiw4tnqEuVaEy39LpkRjP5ESbTcVk`.
    lv_b64 = lv_b64 && `TKkmw2ALLFj9kTfR5rve+aSI3r3FzKWaFQHYIHtJG4mvg8kjhOWh64Xu0QjwSgs8MPUdun3ChBj5RY50irFmTlsoVaJGC6Gs68GOBM5FOJ5jGPC6/iaOmBoadFA/B46PgxCqCheNJZGm1zeT22C+N+YuaC/uiXT942s86vILUEsDBBQAAAAIAHa/RV0z6+O6rQAAAPsB`.
    lv_b64 = lv_b64 && `AAAaAAAAeGwvX3JlbHMvd29ya2Jvb2sueG1sLnJlbHO1kT0OgzAMha8S5QAYqNShAqYurBUXiIL5EYFEsavC7RvBAEgdujBZz5a/92RnLzSKeztR1zsS82gmymXH7B4ApDscFUXW4RQmjfWj4iB9C07pQbUIaRzfwR8ZssiOTFEtDv8h2qbpNT6tfo848Q8wfKwfqENk`.
    lv_b64 = lv_b64 && `KSrlW+Rcwmz2NsFakiiQpSjrXPqyTqSAyxIRLwZpj7Ppk396pT+HXdztV7k1z0e4rSHg9OviC1BLAwQUAAAACAB2v0Vdm4ZChBsBAADXAwAAEwAAAFtDb250ZW50X1R5cGVzXS54bWytk89OwzAMxl+l6nVqMzhwQOsujCvswAuExF2j5p9ib3Rvj9uySqCxDZVLo8b2`.
    lv_b64 = lv_b64 && `93P8Jau3YwTMOmc9VnlDFB+FQNWAk1iGCJ4jdUhOEv+mnYhStXIH4n65fBAqeAJPBfUa+Xq1gVruLWXPHW+jCb7KE1jMs6cxsWdVuYzRGiWJ4+Lg9Q9K8UUouXLIwcZEXHBCnomziCH0K+FU+HqAlIyGbCsTvUjHaaKzAuloAcvLGme6DHVtFOig9o5LSowJpMYGgJwt`.
    lv_b64 = lv_b64 && `R9HFFTTxkGH83s1uYJC5SOTUbQoR2bUEf+edbOmri8hCkMhcOeSEZO3ZJ4TecQ36VjhP+COkdvAExbDMH/N3nyf9Wxp5D6H973vWr6WTxk8NiOE9rz8BUEsBAhQDFAAAAAgAdr9FXUbHTUiVAAAAzQAAABAAAAAAAAAAAAAAAIABAAAAAGRvY1Byb3BzL2FwcC54bWxQ`.
    lv_b64 = lv_b64 && `SwECFAMUAAAACAB2v0VdPYBbgesAAADLAQAAEQAAAAAAAAAAAAAAgAHDAAAAZG9jUHJvcHMvY29yZS54bWxQSwECFAMUAAAACAB2v0VdmVycIxAGAACcJwAAEwAAAAAAAAAAAAAAgAHdAQAAeGwvdGhlbWUvdGhlbWUxLnhtbFBLAQIUAxQAAAAIAHa/RV3nyXMc6gEA`.
    lv_b64 = lv_b64 && `AIsEAAAYAAAAAAAAAAAAAACAgR4IAAB4bC93b3Jrc2hlZXRzL3NoZWV0MS54bWxQSwECFAMUAAAACAB2v0Vd12EvGXUCAADhCgAADQAAAAAAAAAAAAAAgAE+CgAAeGwvc3R5bGVzLnhtbFBLAQIUAxQAAAAIAHa/RV23R+uKwAAAABYCAAALAAAAAAAAAAAAAACAAd4M`.
    lv_b64 = lv_b64 && `AABfcmVscy8ucmVsc1BLAQIUAxQAAAAIAHa/RV3ksGvuMAEAACgCAAAPAAAAAAAAAAAAAACAAccNAAB4bC93b3JrYm9vay54bWxQSwECFAMUAAAACAB2v0VdM+vjuq0AAAD7AQAAGgAAAAAAAAAAAAAAgAEkDwAAeGwvX3JlbHMvd29ya2Jvb2sueG1sLnJlbHNQSwEC`.
    lv_b64 = lv_b64 && `FAMUAAAACAB2v0Vdm4ZChBsBAADXAwAAEwAAAAAAAAAAAAAAgAEJEAAAW0NvbnRlbnRfVHlwZXNdLnhtbFBLBQYAAAAACQAJAD4CAABVEQAAAAA=`.

    DATA(lv_xlsx) = cl_web_http_utility=>decode_x_base64( lv_b64 ).
    zcl_pc_planilha=>ler(
      EXPORTING iv_conteudo  = lv_xlsx
                it_colunas   = VALUE #( ( campo = `CPF` obrigatoria = abap_true ) )
      IMPORTING et_registros = DATA(lt_reg)
                et_erros     = DATA(lt_erros) ).
    " O openpyxl grava os textos em linha (t="inlineStr"), que o XCO não lê:
    " o leitor tem de dizer isso claramente, e não "coluna não encontrada".
    cl_abap_unit_assert=>assert_initial( act = lt_reg ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_erros ) exp = 1 ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lt_erros[ 1 ] CS `inline` ) msg = lt_erros[ 1 ] ).
  ENDMETHOD.

  METHOD xlsx_libreoffice_nao_lido.
    " Limitação conhecida do leitor XCO: o pacote que o LibreOffice grava é
    " recusado ("Invalid content in openxml package"). O usuário precisa receber
    " uma orientação clara (salvar como CSV), não um erro técnico solto.
    DATA lv_b64 TYPE string.
    lv_b64 = lv_b64 && `UEsDBBQACAgIAEUYRl0AAAAAAAAAAAAAAAAaAAAAeGwvX3JlbHMvd29ya2Jvb2sueG1sLnJlbHOtUkFqwzAQvOcVYu+17KSEUiznEgq5pukDhLy2TGxJaDdt8vuqTWgcCKEHn8TMameGYcvVcejFJ0bqvFNQZDkIdMbXnWsVfOzenl5gVc3KLfaa0xeyXSCRdhwpsMzh`.
    lv_b64 = lv_b64 && `VUoyFgdNmQ/o0qTxcdCcYGxl0GavW5TzPF/KONaA6kZTbGoFcVMXIHangP/R9k3TGVx7cxjQ8R0LyWkXk6COLbKCX3gmiyyJgbyfYT5lBuJTj3QNccaP7BdT2n/5uCeLyNcEf1QK9/M87OJ50i6sjli/c0zHNa5kTF/CzEp5c3LVN1BLBwi+0DoZ4AAAAKkCAABQSwME`.
    lv_b64 = lv_b64 && `FAAICAgARRhGXQAAAAAAAAAAAAAAAA8AAAB4bC93b3JrYm9vay54bWyNU9ty2jAQfe9XePQOtoG4wGAy1OBJZnqbkCbPsr3GKrLkkZZbOv33rmWcptM+9AGkvejs2d3jxe25lt4RjBVaxSwcBswDletCqF3Mvj2mgynzLHJVcKkVxOwClt0u3y1O2uwzrfcevVc2ZhVi`.
    lv_b64 = lv_b64 && `M/d9m1dQczvUDSiKlNrUHMk0O982BnhhKwCspT8KgsivuVCsQ5ib/8HQZSlyWOv8UIPCDsSA5EjsbSUay5aLUkh46hryeNN85jXRTrjMmb98pf3VeBnP94cmpeyYlVxaoEYrffqSfYccqSMuJfMKjhDOgkmf8geERsqkMuRsHU8CTvZ3vDUd4p024kUr5HKbGy1lzNAc`.
    lv_b64 = lv_b64 && `rtWIKIr8X5FtO6hHntneeX4WqtCnmNGKLm/uJ3d9FgVWtMBoPJ30vjsQuwpjNg1nI+Yhzx7aQcUsCuhZKYxFV8ShcOrkCFSvtagh/01Hbmf96Sk3UPeyZUrHfUGFnUyQIkdhRSaJsJkLCpj7YuwAexTqNqfxCwRD+Yk+KGIQtpQMlJ90QRArQrvGX3dztdcgkRPHYRAE`.
    lv_b64 = lv_b64 && `YYsLZ/xo0Z1XJUlN97/UJEVmoNOPkxLzDkbE7Mf7aBQl02g0GK3C8SAMNzeDD+PJzSDdpCkNLlkns/QnycqhzumXdPwtGvpGHqDcXmi155htzjnIlePkU1r376j5vSSWvwBQSwcIYLpGyfsBAABvAwAAUEsDBBQACAgIAEUYRl0AAAAAAAAAAAAAAAATAAAAeGwvdGhl`.
    lv_b64 = lv_b64 && `bWUvdGhlbWUxLnhtbM1XwXLbIBC99ysY7gmSLDmyJ3YOST09dKYzTfoBCCGJBiEN0KT++yKwJRQ5rtM6nfqAYXm8XR7sYl/f/Kw5eKJSsUasYHgZQEAFaXImyhX89rC5SCFQGosc80bQFdxSBW/WH67xUle0psAsF2qJV7DSul0ipIgxY3XZtFSYuaKRNdZmKEuUS/xs`.
    lv_b64 = lv_b64 && `aGuOoiCYoxozAXfr5Snrm6JghN415EdNhXYkknKsTeiqYq2CQODaxPjFAsFDFyBc70P9yGm3TnUGwuU9sfH7Kyw2fwy7LyXL7JZL8IT5Cgb2A9H6GvUArqe4wn52uB0gf4wmuLCIF1d5zxc5vimOUkpo2PNZACbE7GLqOy7SMNtzeiDXnXKTIAniMd7jn03wiyzLksUI`.
    lv_b64 = lv_b64 && `Pxvw8QSfBvMYRyN8POCTafyZmZmP8MmAn0+1vlrM4zHegirOxOPBE+xPpocUDf90EJ4aeLo/8AGFvJvj1gv92j2q8fdGbgzAHq65pALobUsLTAzuFteZZBiClmlSbXDN+NYECQGpsFRUmyvSOcdLir1VzkTUCxN64axm4phnzozr83kenCFfECtP7Q8Y5/d6y+lnZQNT`.
    lv_b64 = lv_b64 && `DWf5xhjtwMJ6+dvKdKFl7GfcyF9USjz01Y62VKBtVLejI7ymIjChnS3xUnvsrFQ+4awDnko6uzqNNHSF5UTWMDnGijwVzHUFuKvg4TxyLoAimNO8P17NOP1KiQbcnr62rbRt1rXOy0jiv5BbVTinO73D06RJf6+Mx7qYnU9wnzY+g+LBnymOpjnDxXgEnk2ISZSY7MWt`.
    lv_b64 = lv_b64 && `KYkm2U23bo1TJUoIMC/No06021crlb7DqnJbs6m0f1rEwBclcRf8+QhnaXgeQvRSAFoURs9XLMPQzDmSg7PnB6NDkWXl5j8tgPGJBTB+S6mK96VqnE6Ld8nS6OgO/Cxtsa5A15g7xyTh7qnu0uyh2eemexC6/LxwNahL0p3RJGqYet46qn9fTQeZ0xPP7o2Czt5J0OSA`.
    lv_b64 = lv_b64 && `nskZ5ETT/EKjnx9o8h9gb1n/AlBLBwg7od8K9AIAAAINAABQSwMEFAAICAgARRhGXQAAAAAAAAAAAAAAAA0AAAB4bC9zdHlsZXMueG1s7VhdT9swFH3fr7D8DklKKTClQYyp014mNIqENPZgEiex8EfkuNDw63cdJ2lSYEjdw4qUvtg+uefc4xtbtROerwVHj1SXTMk5`.
    lv_b64 = lv_b64 && `Dg59jKiMVcJkNsc3y8XBKUalITIhXEk6xxUt8Xn0KSxNxel1TqlBoCDLOc6NKT57XhnnVJDyUBVUwpNUaUEMDHXmlYWmJCktSXBv4vszTxAmcRTKlVgIU6JYraSZ40kHIdd8T8DbbIqRk7tUCVj5RiXVhGPv1eDjYXAFv7sDIe4OksQyvCZlFKZKbjJPsQOisHxGj4SD`.
    lv_b64 = lv_b64 && `UmDDY8WVRgamBlo1IomgLuKScHavmQVTIhivHDypeTnRJdTISdWJnfxWEn8oeaGZm1hf0N8bet3Y0jHOBy/NAlFYEGOolgsYoKa/rAoonIQl5GTquHeiM02qYHLcI9QN5L1XOoEl22YOcAuhhJFMScJvijlOCS8p7qCv6km2YBRymhoQ1izLbWtU4VkRY5SATsuxqZ1y`.
    lv_b64 = lv_b64 && `14H0MeX82q7/23Qzex9E1+nL9SrrAWwr673pOqVmQIqCVwtlRYxe0Qb4UocMoAvOMinoVuCVVobGpt6+NRyFpA1EudLsGaTtC8ya7WJ3u2Gxhdx8MTJ0bX4qQ5wKeHrSpFgC2BWRyaRODM/KXDP5sFQL1j2GMhWdDcRV/ECT1mTOEqD2Ir11ulUpf1OnYNc6NT63C9WH`.
    lv_b64 = lv_b64 && `+5Vql8HHMTMZzbxhZue9NZoZzYxmRjOjmV3MTI/26Z9yGuyVm+leuZnsk5uz/2zG6x/f3WG+f47f9Ri/Tl867/v5R+sf7UzfXMDHsr1bNq9Zgb17ZbcaZ7iHIntDn+Mf9qsG71XufsW4YdKNvJeESyUEaeOD4wHh6E0C+uX/7kizAWn2KmmlNZVx1XFOBpzp3ziDXKcD`.
    lv_b64 = lv_b64 && `3slrvCuqY3gHHeVsQHFfDDbFhMHma1X0B1BLBwj9Z83tuQIAAPISAABQSwMEFAAICAgARRhGXQAAAAAAAAAAAAAAABgAAAB4bC93b3Jrc2hlZXRzL3NoZWV0MS54bWy9Vk2P2zYQvfdXCLrHkmjLtha2g8ReNwU2cVBvGqA3WqQsYilSJWl7d399h9SHZWlRLHrIjRw+`.
    lv_b64 = lv_b64 && `vpl5Q81o8fG54N6ZKs2kWPrRKPQ9KlJJmDgu/R+P2w9z39MGC4K5FHTpv1Dtf1z9trhI9aRzSo0HBEIv/dyY8i4IdJrTAuuRLKmAk0yqAhvYqmOgS0UxcZcKHqAwnAYFZsKvGO7UezhklrGUbmR6KqgwFYmiHBsIX+es1A3bM3kXH1H4Aqk28XRC3FQnLV80GfAVLFVS`.
    lv_b64 = lv_b64 && `y8yMUlnUoQ2zTILkJs9nhf4fUxRDqmdmK4UasiJ9T5YFVk+n8gNwl6DUgXFmXlzC/mrh+L8rL2PcUPVVEihyhrmmcFbiI91T86N05+ZRfgdDcxysFkF9ebUgDOphI/MUzZb+p+jufmwRDvAXoxfdWXs6l5ctxHfiWDd0zvi7YuSBCQpWo0618U95WUv+BbSAZ9o9+JuC`.
    lv_b64 = lv_b64 && `aI1BsWMOET7QzLSUBh/2lNPUUNK9tzsZDk72L8VB8paA0AyfuLEhgDupGvsZIl76wsrJgVKW1sWacm7T9L3UYv8A/unE916lLPYp5iBSFIad/Td3vW+1cj7gF3lystSn9ss6SPlkTZY3tEVyWVh5S2y/wjoK38NgPdNrNNd9ddXT/9QFudbLEnfXTWm27sVAqWslQIWf`.
    lv_b64 = lv_b64 && `jJh86c9HcTKbxlMUtzJBUb5QKzlEDdZXKEWzr8WXlcoP9Ew5oF00XRvQV8kFN97rYDbY4NVCyYsHhbAyn7SRRQVqXTTec0YIFa25wv5HOC4WKBzHpbZPo3nvqXVmZdQOAZc1WM+rcBGcIc60RnweIqJbxHqIQLeIzRAxvkXcDxGTFhGAMq086JfKgzphiSp5NJ7E09k8`.
    lv_b64 = lv_b64 && `6euEBhnEPZ0qRNQhG6NkNu9p9YbLSZKMkp5gQxiK31Zs/EsVGw/iilGSzBGazFBPkM/jgWTTnmTjoWQzhHqozdDnfCjYEDTu6RV0PsZSMWF2pRu1Xg7tGMbjtX0fr627b4ER0jTTXCr2KoXBfA3zm6qrWPYnxLB0eBBUc+grVkcGjrlr8OFoFtc9v9lAT3SyHKSBYrll`.
    lv_b64 = lv_b64 && `7maGBcRRNI+iEI2nCIWTme9lUpq3j4J27p1KaLclVXv2Cj03AbE6rd3Nw7o/RvW27Yi+Zyl2ynkn8iIecyp2kCE8G8UgQffDsvRLqYzCDBr5geP06ZMgP3Nm2hHrwe9JZ5yl0NbXsrB/PtpOJHEj6KZk8LBtaI2SV0sqS0bdq4HsKlW2TgCPsCwDtYXZMqWvrlrzjpD7`.
    lv_b64 = lv_b64 && `8/VTWC0kIdUohsfRWcOyYqzM7brrDLbtb+PqX1BLBwjTpv2S1wMAAHoKAABQSwMEFAAICAgARRhGXQAAAAAAAAAAAAAAABQAAAB4bC9zaGFyZWRTdHJpbmdzLnhtbI2RQUoEMRBF954i1N5J60JlSGeQgVkIygh6gCKpmQ50Km0qPeh5XMxB+mJGQdxJdvWp9+t/KLN5`.
    lv_b64 = lv_b64 && `j6M6UZaQuIerVQeK2CUf+NjD68vu8g6UFGSPY2Lq4YMENvbCiBRVrSw9DKVMa63FDRRRVmkirptDyhFLlfmoZcqEXgaiEkd93XU3OmJgUC7NXHq4BTVzeJtp+6utkWDNT8RaJnQ1ud4QyicCu93vjC7W6G/mH+4pRWoDUVyIxCU14ftMy7kNfZ6RS/Do24o8pOUzKY/q`.
    lv_b64 = lv_b64 && `fjnXqcnziDngH6nrZ+wXUEsHCNpyL2vdAAAA1wEAAFBLAwQUAAgICABFGEZdAAAAAAAAAAAAAAAACwAAAF9yZWxzLy5yZWxzrZLBTsMwDIbve4oq9zXdQAihprtMSLshNB7AJG4btYmjxIPy9kQTEgyNssOOcX5//mKl3kxuLN4wJkteiVVZiQK9JmN9p8TL/nF5LzbN`.
    lv_b64 = lv_b64 && `on7GEThHUm9DKnKPT0r0zOFByqR7dJBKCujzTUvRAedj7GQAPUCHcl1VdzL+ZIjmhFnsjBJxZ1ai2H8EvIRNbWs1bkkfHHo+M+JXIpMhdshKTKN8pzi8Eg1lhgp53mV9ucvf75QOGQwwSE0RlyHm7sgW07eOIf2Uy+mYmBO6ueZycGL0Bs28EoQwZ3R7TSN9SEzunxUd`.
    lv_b64 = lv_b64 && `M19Ki1qe/MvmE1BLBwiFmjSa7gAAAM4CAABQSwMEFAAICAgARRhGXQAAAAAAAAAAAAAAABEAAABkb2NQcm9wcy9jb3JlLnhtbJ1SXU+DMBR991eQvkOBzUUJsGSaPbnE6IzGt1ruWBVK096N8e9t2cCvPfl27zmn5341nR/qytuDNqKRGYmCkHggeVMIWWbkab30r4hn`.
    lv_b64 = lv_b64 && `kMmCVY2EjHRgyDy/SLlKeKPhXjcKNAownjWSJuEqI1tElVBq+BZqZgKrkJbcNLpmaFNdUsX4ByuBxmE4ozUgKxgy6gx9NTqSk2XBR0u101VvUHAKFdQg0dAoiOiXFkHX5uyDnvmmrAV2Cs5KB3JUH4wYhW3bBu2kl9r+I/qyunvsR/WFdKviQPL01EjCNTCEwrMGybHc`.
    lv_b64 = lv_b64 && `wDxPbm7XS5LHYTzzo9APZ+swTi6vk+n0NaW/3jvDY9zo3C1UdYfKqUbQCQowXAuF9pZ5T/4AbF4xWe7s4nOF/uKhl4yQO2nFDK7s8TcCikVnPc5gQ2f1Cfv3aINBX1nDXrg/mId90TF1XZvd2ztwPI40JjZGgRUc4SH88y/zT1BLBwjeY4/LYgEAAOMCAABQSwMEFAAI`.
    lv_b64 = lv_b64 && `CAgARRhGXQAAAAAAAAAAAAAAABAAAABkb2NQcm9wcy9hcHAueG1snZDBbsIwDIbve4oq4tomRB1DKA3aNO2EtB06tFuVJS5kapOocVF5+wXQgPN8sn9bn+1frKe+yw4wROtdReYFIxk47Y11u4p81m/5kmQRlTOq8w4qcoRI1vJBfAw+wIAWYpYILlZkjxhWlEa9h17F`.
    lv_b64 = lv_b64 && `IrVd6rR+6BWmcthR37ZWw6vXYw8OKWdsQWFCcAZMHq5AciGuDvhfqPH6dF/c1seQeFLU0IdOIUhBb2ntUXW17UGyJF8L8RxCZ7XC5Ijc2O8B3s8rKC8LXjwVfLaxbpyar+WiWZTZ3USTfvgBjbTkbPYy2s7kXNB73Im9vZgt548FS3Ee+NMEvfkqfwFQSwcIXpYBj/sA`.
    lv_b64 = lv_b64 && `AACcAQAAUEsDBBQACAgIAEUYRl0AAAAAAAAAAAAAAAATAAAAZG9jUHJvcHMvY3VzdG9tLnhtbJ3OsQrCMBSF4d2nCNnbVAeR0rSLODtU95DetgFzb8hNi317I4LujocfPk7TPf1DrBDZEWq5LyspAC0NDictb/2lOEnByeBgHoSg5QYsu3bXXCMFiMkBiywgazmnFGql`.
    lv_b64 = lv_b64 && `2M7gDZc5Yy4jRW9SnnFSNI7Owpns4gGTOlTVUdmFE/kifDn58eo1/UsOZN/v+N5vIXtto35n2xdQSwcI4dYAgJcAAADxAAAAUEsDBBQACAgIAEUYRl0AAAAAAAAAAAAAAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbL1VyU7DMBC96ysiX1HilgNCKG0PLEeoRDkjY08S`.
    lv_b64 = lv_b64 && `03iR7Zb27xknUJXShSoVl1jxzFtmMrHz8VLVyQKcl0YPySDrkwQ0N0Lqckhepg/pNRmPevl0ZcEnmKv9kFQh2BtKPa9AMZ8ZCxojhXGKBXx1JbWMz1gJ9LLfv6Lc6AA6pCFykFF+BwWb1yG5X+J2q4twkty2eVFqSJi1teQsYJjGKN2Jc1D7A8CFFlvu0i9nGSKbHF9J`.
    lv_b64 = lv_b64 && `6y/2K1hdbglIFSuL+7sR7xZ2Q5oAYp6w3U4KSCbMhUemMIEua/oai6Efxs3ejJllaCk7c3l7hDclT1MzRSE5CMPnCiGZtw6Y8BVAQPPNmikm9RH9gGME7XPQ2UNDc0TQh1UN/tzlNqR/aHUD8LRZutf708Sa/1gHKuZAPAeHv/nZG7HJfchHO/D/MeTodOKM9XgUOTi9`.
    lv_b64 = lv_b64 && `3G+9iE4tEoEL8vC3Xisidef+QjxcBIhTtfncB6M6y7c0v8V7OW2uhdEnUEsHCCiZBphzAQAARQYAAFBLAQIUABQACAgIAEUYRl2+0DoZ4AAAAKkCAAAaAAAAAAAAAAAAAAAAAAAAAAB4bC9fcmVscy93b3JrYm9vay54bWwucmVsc1BLAQIUABQACAgIAEUYRl1gukbJ`.
    lv_b64 = lv_b64 && `+wEAAG8DAAAPAAAAAAAAAAAAAAAAACgBAAB4bC93b3JrYm9vay54bWxQSwECFAAUAAgICABFGEZdO6HfCvQCAAACDQAAEwAAAAAAAAAAAAAAAABgAwAAeGwvdGhlbWUvdGhlbWUxLnhtbFBLAQIUABQACAgIAEUYRl39Z83tuQIAAPISAAANAAAAAAAAAAAAAAAAAJUG`.
    lv_b64 = lv_b64 && `AAB4bC9zdHlsZXMueG1sUEsBAhQAFAAICAgARRhGXdOm/ZLXAwAAegoAABgAAAAAAAAAAAAAAAAAiQkAAHhsL3dvcmtzaGVldHMvc2hlZXQxLnhtbFBLAQIUABQACAgIAEUYRl3aci9r3QAAANcBAAAUAAAAAAAAAAAAAAAAAKYNAAB4bC9zaGFyZWRTdHJpbmdzLnht`.
    lv_b64 = lv_b64 && `bFBLAQIUABQACAgIAEUYRl2FmjSa7gAAAM4CAAALAAAAAAAAAAAAAAAAAMUOAABfcmVscy8ucmVsc1BLAQIUABQACAgIAEUYRl3eY4/LYgEAAOMCAAARAAAAAAAAAAAAAAAAAOwPAABkb2NQcm9wcy9jb3JlLnhtbFBLAQIUABQACAgIAEUYRl1elgGP+wAAAJwBAAAQ`.
    lv_b64 = lv_b64 && `AAAAAAAAAAAAAAAAAI0RAABkb2NQcm9wcy9hcHAueG1sUEsBAhQAFAAICAgARRhGXeHWAICXAAAA8QAAABMAAAAAAAAAAAAAAAAAxhIAAGRvY1Byb3BzL2N1c3RvbS54bWxQSwECFAAUAAgICABFGEZdKJkGmHMBAABFBgAAEwAAAAAAAAAAAAAAAACeEwAAW0NvbnRl`.
    lv_b64 = lv_b64 && `bnRfVHlwZXNdLnhtbFBLBQYAAAAACwALAMECAABSFQAAAAA=`.

    zcl_pc_planilha=>ler(
      EXPORTING iv_conteudo  = cl_web_http_utility=>decode_x_base64( lv_b64 )
                it_colunas   = VALUE #( ( campo = `CPF` obrigatoria = abap_true ) )
      IMPORTING et_registros = DATA(lt_reg)
                et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_reg ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_erros ) exp = 1 ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lt_erros[ 1 ] CS `.csv` ) msg = lt_erros[ 1 ] ).
  ENDMETHOD.

  METHOD xlsx_de_xlsxwriter.
    " XLSX gerado pelo xlsxwriter, que reproduz o pacote do Excel (sharedStrings,
    " estilos, tema), com células de tipos diferentes: CPF numérico (sem zero à
    " esquerda), data de verdade, preço decimal e inteiro.
    "   CPF         | Nome          | Nascimento | Preço  | Quantidade
    "   1234567890  | João da Ação  | 15/04/1990 | 1499.9 | 25
    "   52998224725 | Maria         | 01/12/2001 | 89.9   | 3
    DATA lv_b64 TYPE string.
    lv_b64 = lv_b64 && `UEsDBBQAAAAIAAAAPwBhXUk6TwEAAI8EAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbK2Uy27CMBBF9/2KyNsqMXRRVRWBRR/LFqn0A1x7Qiwc2/IMFP6+k/BQW1Gggk2sZO7cc8eOPBgtG5ctIKENvhT9oicy8DoY66eleJ8853ciQ1LeKBc8lGIFKEbDq8FkFQEzbvZY`.
    lv_b64 = lv_b64 && `ipoo3kuJuoZGYREieK5UITWK+DVNZVR6pqYgb3q9W6mDJ/CUU+shhoNHqNTcUfa05M/rIAkciuxhLWxZpVAxOqsVcV0uvPlFyTeEgjs7DdY24jULhNxLaCt/AzZ9r7wzyRrIxirRi2pYJU3Q4xQiStYXh132xAxVZTWwx7zhlgLaQAZMHtkSElnYZT7I1iHB/+HbPWq7`.
    lv_b64 = lv_b64 && `TyQunURaOcCzR8WYQBmsAahxxdr0CJn4f4L1s382v7M5AvwMafYRwuzSw7Zr0SjrT+B3YpTdcv7UP4Ps/I8dea0SmDdKfA1c/OS/e29zyO4+GX4BUEsDBBQAAAAIAAAAPwDyn0na6QAAAEsCAAALAAAAX3JlbHMvLnJlbHOtksFOwzAMQO98ReT7mm5ICKGluyCk3SY0`.
    lv_b64 = lv_b64 && `PsAkbhu1jaPEg+7viZBADI1pB45x7Odny+vNPI3qjVL2HAwsqxoUBcvOh87Ay/5pcQ8qCwaHIwcycKQMm+Zm/UwjSqnJvY9ZFUjIBnqR+KB1tj1NmCuOFMpPy2lCKc/U6Yh2wI70qq7vdPrJgOaEqbbOQNq6Jaj9MdI1bG5bb+mR7WGiIGda/MooZEwdiYF51O+chlfm`.
    lv_b64 = lv_b64 && `oSpQ0OddVte7/D2nnkjQoaC2nGgRU6lO4stav3Uc210J58+MS0K3/7kcmoWCI3dZCWP8MtInN9B8AFBLAwQUAAAACAAAAD8ARHVb8OgAAAC5AgAAGgAAAHhsL19yZWxzL3dvcmtib29rLnhtbC5yZWxzrZLBasMwEETv/Qqx91p2EkopkXMphVzb9AOEtLZMbElot2n9`.
    lv_b64 = lv_b64 && `9xEJTR0IoQefxIzYmQe7683P0IsDJuqCV1AVJQj0JtjOtwo+d2+PzyCItbe6Dx4VjEiwqR/W79hrzjPkukgih3hS4Jjji5RkHA6aihDR558mpEFzlqmVUZu9blEuyvJJpmkG1FeZYmsVpK2tQOzGiP/JDk3TGXwN5mtAzzcq5HdIe3KInEN1apEVXCySp6cqcirI2zCL`.
    lv_b64 = lv_b64 && `OWE4z+IfyEmezbsMyzkZiMc+L/QCcdb36lez1jud0H5wytc2pZjavzDy6uLqI1BLAwQUAAAACAAAAD8ABaaeibABAADcAwAAGAAAAHhsL3dvcmtzaGVldHMvc2hlZXQxLnhtbI2TQW/bIBiG7/sViPuCg+PYjmxX7ZJqO0yauq13Yn+2UW2wgCbbvx/YbURYDvWJj0e8`.
    lv_b64 = lv_b64 && `PB+G4u7POKATKM2lKPF6FWEEopYNF12Jf/96/JxhpA0TDRukgBL/BY3vqk/FWaoX3QMYZAOELnFvzLQjRNc9jEyv5ATCklaqkRlbqo7oSQFr5kXjQGgUbcnIuMBLwk59JEO2La9hL+vXEYRZQhQMzFh93fNJ46pouGWuH6SgLfH9eneIMamKeednDmftjZFhx58wQG2g`.
    lv_b64 = lv_b64 && `sf1j5Bo7Svni4Dc7Fbml5L+1j7PUD4UaaNnrYJ7k+Svwrjc2JLnstmeGVYWSZ6TmcD0xd1brXWI9azd5b2ftGud9qqKCnOxm9Rt78Nn6mn3xGb1me5/F1+zgs82FEet4EaU3RemiQeNNsk2zPHSlXm4SuLpA1//sQ/M0C3zfojd5vsoD3QXR5LZpfNM0XiRonmeUblIa`.
    lv_b64 = lv_b64 && `6DzEnuo2UI191ZTSgO+X7MyKRt4X/JxDHBz9Ik28OzGxDr4z1XGh0QCt9YlWKUZquULz2MhpHiUYHaUxcnyvevuMQLnK2rZSmvfC3dTLw6z+AVBLAwQUAAAACAAAAD8AgxhqJUgBAAAmAgAADwAAAHhsL3dvcmtib29rLnhtbI1Ry07DMBC88xXW3mkeaiNaNanES1RC`.
    lv_b64 = lv_b64 && `gERpzybeNFYdO7Id0v4961QpcOO0M+Pd0c56uTo2in2hddLoHJJJDAx1aYTU+xw+No/XN8Cc51pwZTTmcEIHq+Jq2Rt7+DTmwGheuxxq79tFFLmyxoa7iWlR00tlbMM9UbuPXGuRC1cj+kZFaRxnUcOlhrPDwv7Hw1SVLPHelF2D2p9NLCruaXtXy9ZBsaykwu05EONt`.
    lv_b64 = lv_b64 && `+8IbWvuogCnu/IOQHkUOU6Kmxz+C7drbTqpAZvEMouIS8s0ygRXvlN/QaqM7nSudpmkWOkPXVmLvfoYCZced1ML0OaRTuuxpZMkMWD/gnRS+JiGL5xftCeW+9jnMsywO5tEv9+F+Y2V6CPcecEL/FOqa9idsF5KAXYtkcBjHSq5KShPK0JhOZ8kcWNUpdUfaq342fDAI`.
    lv_b64 = lv_b64 && `Q2OS4htQSwMEFAAAAAgAAAA/AAmyro7NAAAARAEAABQAAAB4bC9zaGFyZWRTdHJpbmdzLnhtbGWQwUoDMRBA735FmHub1YOKZFOk0IOgVNAPGDZjN7CZbDOzot/joR+yP2ZEROje5r3HzGHc5iMN5p2KxMwtXK4bMMRdDpEPLby+7Fa3YESRAw6ZqYVPEtj4Cyeipq6y`.
    lv_b64 = lv_b64 && `tNCrjnfWStdTQlnnkbiWt1wSasVysDIWwiA9kabBXjXNtU0YGUyXJ9YWbsBMHI8Tbf/YO4neqd/ud86qd/YHf9VTTrRwKF1MxJrPy77QfFrY5wlZY8CwuPSQ569sApr7+VSn8/yIJeK/tPUN/htQSwMEFAAAAAgAAAA/ADcb4XrCAQAABgQAAA0AAAB4bC9zdHlsZXMu`.
    lv_b64 = lv_b64 && `eG1snZNNa9wwEIbv/RVC90a7JlnaYjuHwEIgDYVsoFfZkr0CfRhpvKz76zuyFK8NhZb6otGrmWfGM1L5eDWaXKQPytmK7u92lEjbOqFsX9H30/HzF0oCcCu4dlZWdJKBPtafygCTlm9nKYEgwYaKngGGb4yF9iwND3dukBZPOucNB9z6noXBSy5CDDKaFbvdgRmuLK1L`.
    lv_b64 = lv_b64 && `O5qjgUBaN1rAMhaJpOVZoHi4pyThnpzAUoRgxrAJP8rqkmVGXXbOblFRqMvwi1y4RmUf3VunnSeAtcrohIrlRiaPJ65V41UUO26UnpJcRGH+vexnlHV+zp0yzEssQGm9FFDQJNTlwAGkt0fckGyfpgHTW+xswsx+f/HuPZ/2xcMqYF4wb+O8wEmufz1JdallBxjgVX+O`.
    lv_b64 = lv_b64 && `K7iBxUMAZ9AQivfOch2RHxHZQGwrtX6L4/7ZbdjXbjWdXZyNXUwsKJsJkzaRv6Yl9gpb/BeWXLuFv4nOV+af4wkfBj29jqaR/jjftHw3WK5z1YxNKxaVxFtU0dcYrFfgZlQalP1DG5AprrcOzKfAG3xcmyzIELLjo4bTcljRm/1dCjWar4vXD3VxkL1u9kuc//4wV3B7`.
    lv_b64 = lv_b64 && `wfVvUEsDBBQAAAAIAAAAPwAY+kZUsAUAAFIbAAATAAAAeGwvdGhlbWUvdGhlbWUxLnhtbO1ZTY/bRBi+8ytGvreOEzvNrpqtNtmkhe22q920qMeJPbGnGXusmcluc0PtEQkJURAXJG4cEFCplbiUX7NQBEXqX+D1R5LxZrLNtosAtTkknvHzfn/4HefqtQcxQ0dESMqT`.
    lv_b64 = lv_b64 && `tuVcrlmIJD4PaBK2rTuD/qWWhaTCSYAZT0jbmhJpXdv64CreVBGJCQLyRG7ithUplW7atvRhG8vLPCUJ3BtxEWMFSxHagcDHwDZmdr1Wa9oxpomFEhwD19ujEfUJGmQsra0Z8x6Dr0TJbMNn4tDPJeoUOTYYO9mPnMouE+gIs7YFcgJ+PCAPlIUYlgputK1a/rHsrav2`.
    lv_b64 = lv_b64 && `nIipFbQaXT//lHQlQTCu53QiHM4Jnb67cWVnzr9e8F/G9Xq9bs+Z88sB2PfBUmcJ6/ZbTmfGUwMVl8u8uzWv5lbxGv/GEn6j0+l4GxV8Y4F3l/CtWtPdrlfw7gLvLevf2e52mxW8t8A3l/D9KxtNt4rPQRGjyXgJncVzHpk5ZMTZDSO8BfDWLAEWKFvLroI+UatyLcb3`.
    lv_b64 = lv_b64 && `uegDIA8uVjRBapqSEfYB18XxUFCcCcCbBGt3ii1fLm1lspD0BU1V2/ooxVARC8ir5z+8ev4UvXr+5OThs5OHP588enTy8CcD4Q2chDrhy+8+/+ubT9CfT799+fhLM17q+N9+/PTXX74wA5UOfPHVk9+fPXnx9Wd/fP/YAN8WeKjDBzQmEt0ix+iAx2CbQQAZivNRDCJM`.
    lv_b64 = lv_b64 && `KxQ4AqQB2FNRBXhripkJ1yFV590V0ABMwOuT+xVdDyMxUdQA3I3iCnCPc9bhwmjObiZLN2eShGbhYqLjDjA+Msnungptb5JCJlMTy25EKmruM4g2DklCFMru8TEhBrJ7lFb8ukd9wSUfKXSPog6mRpcM6FCZiW7QGOIyNSkIoa74Zu8u6nBmYr9DjqpIKAjMTCwJq7jx`.
    lv_b64 = lv_b64 && `Op4oHBs1xjHTkTexikxKHk6FX3G4VBDpkDCOegGR0kRzW0wr6u5i6ETGsO+xaVxFCkXHJuRNzLmO3OHjboTj1KgzTSId+6EcQ4pitM+VUQlerZBsDXHAycpw36VEna+s79AwMidIdmciyq5d6b8xTc5qxoxCN37fjGfwbXg0mUridAtehfsfNt4dPEn2CeT6+777vu++`.
    lv_b64 = lv_b64 && `i313VS2v220XDdbW5+KcX7xySB5Rxg7VlJGbMm/NEpQO+rCZL3Ki+UyeRnBZiqvgQoHzayS4+piq6DDCKYhxcgmhLFmHEqVcwknAWsk7P05SMD7f82ZnQEBjtceDYruhnw3nbPJVKHVBjYzBusIaV95OmFMA15TmeGZp3pnSbM2bUA0IZwd/p1kvREPGYEaCzO8Fg1lY`.
    lv_b64 = lv_b64 && `LjxEMsIBKWPkGA1xGmu6rfV6r2nSNhpvJ22dIOni3BXivAuIUm0pSvZyObKkukLHoJVX9yzk47RtjWCSgss4BX4ya0CYhUnb8lVpymuL+bTB5rR0aisNrohIhVQ7WEYFVX5r9uokWehf99zMDxdjgKEbradFo+X8i1rYp0NLRiPiqxU7i2V5j08UEYdRcIyGbCIOMOjt`.
    lv_b64 = lv_b64 && `FtkVUAnPjPpsIaBC3TLxqpVfVsHpVzRldWCWRrjsSS0t9gU8v57rkK809ewVur+hKY0LNMV7d03JMhfG1kaQH6hgDBAYZTnatrhQEYculEbU7wsYHHJZoBeCsshUQix735zpSo4WfavgUTS5MFIHNESCQqdTkSBkX5V2voaZU9efrzNGZZ+ZqyvT4ndIjggbZNXbzOy3`.
    lv_b64 = lv_b64 && `UDTrJqUjctzpoNmm6hqG/f/w5OOumHzOHg8WgtzzzCKu1vS1R8HG26lwzkdt3Wxx3Vv7UZvC4QNlX9C4qfDZYr4d8AOIPppPlAgS8VKrLL/55hB0bmnGZaz+2TFqEYLWinhf5PCpObuxwtlni3tzZ3sGX3tnu9peLlFbO8jkq6U/nvjwPsjegYPShClZvE16AEfN7uwv`.
    lv_b64 = lv_b64 && `A+BjL0i3/gZQSwMEFAAAAAgAAAA/AAxs5kckAQAAUAIAABEAAABkb2NQcm9wcy9jb3JlLnhtbJ2SzWrDMBCE730Ko7st2aamCNuBtuTUQKEpLb0JaZOIWj9Iah2/fRU7cRLIqcfVzH47u6he7FWX/ILz0ugG5RlBCWhuhNTbBr2vl+kDSnxgWrDOaGjQAB4t2ruaW8qN`.
    lv_b64 = lv_b64 && `g1dnLLggwScRpD3ltkG7ECzF2PMdKOaz6NBR3BinWIil22LL+DfbAi4IqbCCwAQLDB+AqZ2J6IgUfEbaH9eNAMExdKBAB4/zLMdnbwCn/M2GUblwKhkGCzetJ3F2772cjX3fZ305WmP+HH+uXt7GVVOpD6figNpacModsGBcW+PLIh6uYz6s4ok3EsTjEPUbb8dFpj4Q`.
    lv_b64 = lv_b64 && `SQxAp7gn5aN8el4vUVuQokpzkpJqTUpK7impvg4jr/rPQHUc8m/iCTDlvv4E7R9QSwMEFAAAAAgAAAA/AF66p9N3AQAAEAMAABAAAABkb2NQcm9wcy9hcHAueG1snZLBTuswEEX3fEXkPXVSIfRUOUaogFjwRKUWWBtn0lg4tuUZopavx0nVkAIrsrozc3V9Mra42rU2`.
    lv_b64 = lv_b64 && `6yCi8a5kxSxnGTjtK+O2JXva3J3/YxmScpWy3kHJ9oDsSp6JVfQBIhnALCU4LFlDFBaco26gVThLY5cmtY+tolTGLfd1bTTceP3egiM+z/NLDjsCV0F1HsZAdkhcdPTX0Mrrng+fN/uQ8qS4DsEarSj9pPxvdPToa8pudxqs4NOhSEFr0O/R0F7mgk9LsdbKwjIFy1pZ`.
    lv_b64 = lv_b64 && `BMG/GuIeVL+zlTIRpeho0YEmHzM0H2lrc5a9KoQep2SdikY5YgfboRi0DUhRvvj4hg0AoeBjc5BT71SbC1kMhiROjXwESfoUcWPIAj7WKxXpF+JiSjwwsAnjuucrfvAdT/qWvfRtUC4tkI/qwbg3fAobf6MIjus8bYp1oyJU6QbGdY8NcZ+4ou39y0a5LVRHz89Bf/nP`.
    lv_b64 = lv_b64 && `hwcui/ksT99w58ee4F9vWX4CUEsBAhQDFAAAAAgAAAA/AGFdSTpPAQAAjwQAABMAAAAAAAAAAAAAAICBAAAAAFtDb250ZW50X1R5cGVzXS54bWxQSwECFAMUAAAACAAAAD8A8p9J2ukAAABLAgAACwAAAAAAAAAAAAAAgIGAAQAAX3JlbHMvLnJlbHNQSwECFAMUAAAA`.
    lv_b64 = lv_b64 && `CAAAAD8ARHVb8OgAAAC5AgAAGgAAAAAAAAAAAAAAgIGSAgAAeGwvX3JlbHMvd29ya2Jvb2sueG1sLnJlbHNQSwECFAMUAAAACAAAAD8ABaaeibABAADcAwAAGAAAAAAAAAAAAAAAgIGyAwAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sUEsBAhQDFAAAAAgAAAA/AIMY`.
    lv_b64 = lv_b64 && `aiVIAQAAJgIAAA8AAAAAAAAAAAAAAICBmAUAAHhsL3dvcmtib29rLnhtbFBLAQIUAxQAAAAIAAAAPwAJsq6OzQAAAEQBAAAUAAAAAAAAAAAAAACAgQ0HAAB4bC9zaGFyZWRTdHJpbmdzLnhtbFBLAQIUAxQAAAAIAAAAPwA3G+F6wgEAAAYEAAANAAAAAAAAAAAAAACA`.
    lv_b64 = lv_b64 && `gQwIAAB4bC9zdHlsZXMueG1sUEsBAhQDFAAAAAgAAAA/ABj6RlSwBQAAUhsAABMAAAAAAAAAAAAAAICB+QkAAHhsL3RoZW1lL3RoZW1lMS54bWxQSwECFAMUAAAACAAAAD8ADGzmRyQBAABQAgAAEQAAAAAAAAAAAAAAgIHaDwAAZG9jUHJvcHMvY29yZS54bWxQSwEC`.
    lv_b64 = lv_b64 && `FAMUAAAACAAAAD8AXrqn03cBAAAQAwAAEAAAAAAAAAAAAAAAgIEtEQAAZG9jUHJvcHMvYXBwLnhtbFBLBQYAAAAACgAKAIACAADSEgAAAAA=`.

    DATA(lv_xlsx) = cl_web_http_utility=>decode_x_base64( lv_b64 ).
    zcl_pc_planilha=>ler(
      EXPORTING iv_conteudo  = lv_xlsx
                it_colunas   = VALUE #( ( campo = `CPF` obrigatoria = abap_true )
                                        ( campo = `Nome` )
                                        ( campo = `Nascimento` )
                                        ( campo = `Preço` )
                                        ( campo = `Quantidade` ) )
      IMPORTING et_registros = DATA(lt_reg)
                et_erros     = DATA(lt_erros) ).
    cl_abap_unit_assert=>assert_initial( act = lt_erros msg = concat_lines_of( table = lt_erros sep = ` | ` ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_reg ) exp = 2 ).

    DATA(lv_cpf)   = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `CPF` ).
    DATA(lv_nasc)  = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `Nascimento` ).
    DATA(lv_preco) = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `Preço` ).
    DATA(lv_qtde)  = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `Quantidade` ).

    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>valor( is_registro = lt_reg[ 1 ] iv_campo = `Nome` )
                                        exp = `João da Ação` ).
    " Valores crus (número, serial de data...) precisam ser entendidos pelas
    " rotinas de conversão: CPF completa zeros, data serial e decimal
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>normalizar_cpf( lv_cpf ) exp = `01234567890`
                                        msg = |CPF cru: { lv_cpf }| ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>para_data( lv_nasc ) exp = CONV d( '19900415' )
                                        msg = |Data crua: { lv_nasc }| ).
    zcl_pc_planilha=>para_decimal( EXPORTING iv_texto = lv_preco IMPORTING ev_valor = DATA(lv_dec) ev_valido = DATA(lv_ok) ).
    cl_abap_unit_assert=>assert_true( act = lv_ok msg = |Preço cru: { lv_preco }| ).
    cl_abap_unit_assert=>assert_equals( act = lv_dec exp = CONV decfloat34( '1499.9' ) ).
    zcl_pc_planilha=>para_inteiro( EXPORTING iv_texto = lv_qtde IMPORTING ev_valor = DATA(lv_int) ev_valido = DATA(lv_ok2) ).
    cl_abap_unit_assert=>assert_true( act = lv_ok2 msg = |Quantidade crua: { lv_qtde }| ).
    cl_abap_unit_assert=>assert_equals( act = lv_int exp = 25 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>normalizar_cpf( zcl_pc_planilha=>valor( is_registro = lt_reg[ 2 ] iv_campo = `CPF` ) )
                                        exp = `52998224725` ).
  ENDMETHOD.

  METHOD datas.
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>para_data( `1990-04-15` ) exp = CONV d( '19900415' ) ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>para_data( `15/04/1990` ) exp = CONV d( '19900415' ) ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>para_data( `5/4/1990` )   exp = CONV d( '19900405' ) ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>para_data( `19900415` )   exp = CONV d( '19900415' ) ).
    " 32978 = 15/04/1990 no calendário do Excel
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_planilha=>para_data( `32978` )      exp = CONV d( '19900415' ) ).
    cl_abap_unit_assert=>assert_initial( act = zcl_pc_planilha=>para_data( `31/02/1990` ) ).
    cl_abap_unit_assert=>assert_initial( act = zcl_pc_planilha=>para_data( `13/13/1990` ) ).
    cl_abap_unit_assert=>assert_initial( act = zcl_pc_planilha=>para_data( `abc` ) ).
    cl_abap_unit_assert=>assert_initial( act = zcl_pc_planilha=>para_data( `` ) ).
  ENDMETHOD.

  METHOD decimais_e_inteiros.
    zcl_pc_planilha=>para_decimal( EXPORTING iv_texto = `3499.90` IMPORTING ev_valor = DATA(lv1) ev_valido = DATA(lok1) ).
    cl_abap_unit_assert=>assert_true( lok1 ).
    cl_abap_unit_assert=>assert_equals( act = lv1 exp = CONV decfloat34( '3499.9' ) ).

    zcl_pc_planilha=>para_decimal( EXPORTING iv_texto = `3499,90` IMPORTING ev_valor = DATA(lv2) ev_valido = DATA(lok2) ).
    cl_abap_unit_assert=>assert_true( lok2 ).
    cl_abap_unit_assert=>assert_equals( act = lv2 exp = CONV decfloat34( '3499.9' ) ).

    zcl_pc_planilha=>para_decimal( EXPORTING iv_texto = `R$ 1.499,90` IMPORTING ev_valor = DATA(lv3) ev_valido = DATA(lok3) ).
    cl_abap_unit_assert=>assert_true( lok3 ).
    cl_abap_unit_assert=>assert_equals( act = lv3 exp = CONV decfloat34( '1499.9' ) ).

    zcl_pc_planilha=>para_decimal( EXPORTING iv_texto = `1,499.90` IMPORTING ev_valor = DATA(lv4) ev_valido = DATA(lok4) ).
    cl_abap_unit_assert=>assert_true( lok4 ).
    cl_abap_unit_assert=>assert_equals( act = lv4 exp = CONV decfloat34( '1499.9' ) ).

    zcl_pc_planilha=>para_decimal( EXPORTING iv_texto = `abc` IMPORTING ev_valido = DATA(lok5) ).
    cl_abap_unit_assert=>assert_false( lok5 ).
    zcl_pc_planilha=>para_decimal( EXPORTING iv_texto = `` IMPORTING ev_valido = DATA(lok6) ).
    cl_abap_unit_assert=>assert_false( lok6 ).

    zcl_pc_planilha=>para_inteiro( EXPORTING iv_texto = `25` IMPORTING ev_valor = DATA(li1) ev_valido = DATA(liok1) ).
    cl_abap_unit_assert=>assert_true( liok1 ).
    cl_abap_unit_assert=>assert_equals( act = li1 exp = 25 ).

    zcl_pc_planilha=>para_inteiro( EXPORTING iv_texto = `25.0` IMPORTING ev_valor = DATA(li2) ev_valido = DATA(liok2) ).
    cl_abap_unit_assert=>assert_true( liok2 ).
    cl_abap_unit_assert=>assert_equals( act = li2 exp = 25 ).

    zcl_pc_planilha=>para_inteiro( EXPORTING iv_texto = `2,5` IMPORTING ev_valido = DATA(liok3) ).
    cl_abap_unit_assert=>assert_false( liok3 ).
  ENDMETHOD.

ENDCLASS.
