"! <p class="shorttext synchronized">Pedidos de Compras - Utilitários</p>
"! Funções puras (sem acesso a banco) reutilizadas pelos três BOs.
CLASS zcl_pc_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Remove tudo que não for dígito (CPF, CEP, telefone, cartão).
    CLASS-METHODS somente_digitos
      IMPORTING iv_valor        TYPE csequence
      RETURNING VALUE(rv_valor) TYPE string.

    "! Valida CPF: 11 dígitos, não repetidos e dígitos verificadores.
    CLASS-METHODS validar_cpf
      IMPORTING iv_cpf           TYPE csequence
      RETURNING VALUE(rv_valido) TYPE abap_boolean.

    "! Calcula os 2 dígitos verificadores para uma base de 9 dígitos.
    CLASS-METHODS calcular_dv_cpf
      IMPORTING iv_base9      TYPE csequence
      RETURNING VALUE(rv_cpf) TYPE string.

    "! Formata CPF (somente dígitos) como 000.000.000-00.
    CLASS-METHODS formatar_cpf
      IMPORTING iv_cpf              TYPE csequence
      RETURNING VALUE(rv_formatado) TYPE string.

    "! Formata telefone (10/11 dígitos) como (00) 00000-0000.
    CLASS-METHODS formatar_telefone
      IMPORTING iv_telefone         TYPE csequence
      RETURNING VALUE(rv_formatado) TYPE string.

    CLASS-METHODS validar_email
      IMPORTING iv_email         TYPE csequence
      RETURNING VALUE(rv_valido) TYPE abap_boolean.

    "! Aceita somente JPEG/PNG/WEBP: MIME type, extensão e assinatura binária.
    "! Conteúdo vazio é considerado válido (foto opcional).
    CLASS-METHODS validar_imagem
      IMPORTING iv_conteudo      TYPE xstring
                iv_mime_type     TYPE csequence
                iv_nome_arquivo  TYPE csequence
      RETURNING VALUE(rv_valida) TYPE abap_boolean.

    "! SEM_ESTOQUE (0), ACABANDO (1-10) ou EM_ESTOQUE (>= 11).
    CLASS-METHODS calcular_status_estoque
      IMPORTING iv_qtde_disponivel TYPE i
      RETURNING VALUE(rv_status)   TYPE zif_pc_constants=>ty_status_estoque.

    CLASS-METHODS formatar_endereco
      IMPORTING iv_logradouro      TYPE csequence
                iv_numero          TYPE csequence
                iv_complemento     TYPE csequence OPTIONAL
                iv_bairro          TYPE csequence
                iv_cidade          TYPE csequence
                iv_uf              TYPE csequence
                iv_cep             TYPE csequence
      RETURNING VALUE(rv_endereco) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_pc_util IMPLEMENTATION.

  METHOD somente_digitos.
    rv_valor = replace( val  = iv_valor
                        pcre = `[^0-9]`
                        with = ``
                        occ  = 0 ).
  ENDMETHOD.


  METHOD validar_cpf.
    rv_valido = abap_false.

    DATA(lv_cpf) = somente_digitos( iv_cpf ).
    IF strlen( lv_cpf ) <> 11.
      RETURN.
    ENDIF.

    " Rejeita sequências repetidas (000..., 111..., etc.)
    IF lv_cpf = repeat( val = substring( val = lv_cpf off = 0 len = 1 ) occ = 11 ).
      RETURN.
    ENDIF.

    IF calcular_dv_cpf( substring( val = lv_cpf off = 0 len = 9 ) ) = lv_cpf.
      rv_valido = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD calcular_dv_cpf.
    DATA lv_soma  TYPE i.
    DATA lv_resto TYPE i.

    rv_cpf = somente_digitos( iv_base9 ).
    IF strlen( rv_cpf ) <> 9.
      CLEAR rv_cpf.
      RETURN.
    ENDIF.

    " 1º dígito: pesos 10..2 / 2º dígito: pesos 11..2
    DO 2 TIMES.
      DATA(lv_tamanho) = strlen( rv_cpf ).
      CLEAR lv_soma.
      DO lv_tamanho TIMES.
        DATA(lv_pos) = sy-index - 1.
        lv_soma += CONV i( substring( val = rv_cpf off = lv_pos len = 1 ) ) * ( lv_tamanho + 1 - lv_pos ).
      ENDDO.
      lv_resto = ( lv_soma * 10 ) MOD 11.
      IF lv_resto = 10.
        lv_resto = 0.
      ENDIF.
      rv_cpf = rv_cpf && condense( CONV string( lv_resto ) ).
    ENDDO.
  ENDMETHOD.


  METHOD formatar_cpf.
    DATA(lv_cpf) = somente_digitos( iv_cpf ).
    IF strlen( lv_cpf ) <> 11.
      rv_formatado = lv_cpf.
      RETURN.
    ENDIF.
    rv_formatado = |{ lv_cpf(3) }.{ lv_cpf+3(3) }.{ lv_cpf+6(3) }-{ lv_cpf+9(2) }|.
  ENDMETHOD.


  METHOD formatar_telefone.
    DATA(lv_tel) = somente_digitos( iv_telefone ).
    CASE strlen( lv_tel ).
      WHEN 11.
        rv_formatado = |({ lv_tel(2) }) { lv_tel+2(5) }-{ lv_tel+7(4) }|.
      WHEN 10.
        rv_formatado = |({ lv_tel(2) }) { lv_tel+2(4) }-{ lv_tel+6(4) }|.
      WHEN OTHERS.
        rv_formatado = lv_tel.
    ENDCASE.
  ENDMETHOD.


  METHOD validar_email.
    DATA(lv_email) = condense( to_lower( iv_email ) ).
    rv_valido = xsdbool( matches( val  = lv_email
                                  pcre = `^[a-z0-9._%+\-]+@[a-z0-9\-]+(\.[a-z0-9\-]+)*\.[a-z]{2,}$` ) ).
  ENDMETHOD.


  METHOD calcular_status_estoque.
    IF iv_qtde_disponivel <= 0.
      rv_status = zif_pc_constants=>c_status_estoque-sem_estoque.
    ELSEIF iv_qtde_disponivel <= zif_pc_constants=>c_limite_acabando.
      rv_status = zif_pc_constants=>c_status_estoque-acabando.
    ELSE.
      rv_status = zif_pc_constants=>c_status_estoque-em_estoque.
    ENDIF.
  ENDMETHOD.


  METHOD validar_imagem.
    CONSTANTS lc_assinatura_png  TYPE x LENGTH 8 VALUE '89504E470D0A1A0A'.
    CONSTANTS lc_assinatura_jpeg TYPE x LENGTH 3 VALUE 'FFD8FF'.
    " WEBP é um contêiner RIFF: "RIFF" + tamanho (4 bytes) + "WEBP"
    CONSTANTS lc_assinatura_riff TYPE x LENGTH 4 VALUE '52494646'.
    CONSTANTS lc_assinatura_webp TYPE x LENGTH 4 VALUE '57454250'.

    IF iv_conteudo IS INITIAL.
      rv_valida = abap_true.
      RETURN.
    ENDIF.

    rv_valida = abap_false.

    DATA(lv_mime) = condense( to_lower( iv_mime_type ) ).
    DATA(lv_nome) = condense( to_lower( iv_nome_arquivo ) ).

    " 1) MIME type permitido
    IF lv_mime <> zif_pc_constants=>c_mime-jpeg
       AND lv_mime <> zif_pc_constants=>c_mime-png
       AND lv_mime <> zif_pc_constants=>c_mime-webp.
      RETURN.
    ENDIF.

    " 2) Extensão permitida (quando o nome do arquivo for informado)
    IF lv_nome IS NOT INITIAL
       AND NOT matches( val = lv_nome pcre = `.*\.(jpe?g|png|webp)$` ).
      RETURN.
    ENDIF.

    " 3) Assinatura binária (magic bytes) compatível com o MIME type
    CASE lv_mime.
      WHEN zif_pc_constants=>c_mime-png.
        IF xstrlen( iv_conteudo ) >= 8 AND iv_conteudo(8) = lc_assinatura_png.
          rv_valida = abap_true.
        ENDIF.
      WHEN zif_pc_constants=>c_mime-webp.
        IF xstrlen( iv_conteudo ) >= 12
           AND iv_conteudo(4) = lc_assinatura_riff
           AND iv_conteudo+8(4) = lc_assinatura_webp.
          rv_valida = abap_true.
        ENDIF.
      WHEN OTHERS.
        IF xstrlen( iv_conteudo ) >= 3 AND iv_conteudo(3) = lc_assinatura_jpeg.
          rv_valida = abap_true.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD formatar_endereco.
    DATA(lv_cep) = somente_digitos( iv_cep ).
    IF strlen( lv_cep ) = 8.
      lv_cep = |{ lv_cep(5) }-{ lv_cep+5(3) }|.
    ENDIF.

    rv_endereco = |{ condense( iv_logradouro ) }, { condense( iv_numero ) }|.
    IF condense( iv_complemento ) <> ``.
      rv_endereco = |{ rv_endereco } - { condense( iv_complemento ) }|.
    ENDIF.
    rv_endereco = |{ rv_endereco } - { condense( iv_bairro ) } - { condense( iv_cidade ) }/{ condense( iv_uf ) } - CEP { lv_cep }|.
  ENDMETHOD.

ENDCLASS.
