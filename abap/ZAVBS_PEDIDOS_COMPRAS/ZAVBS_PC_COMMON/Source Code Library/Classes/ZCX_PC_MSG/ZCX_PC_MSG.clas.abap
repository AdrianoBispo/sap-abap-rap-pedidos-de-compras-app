"! <p class="shorttext synchronized">Pedidos de Compras - Mensagens RAP (T100)</p>
"! Classe de mensagens usada em todos os BOs. Os textos ficam na
"! Message Class ZPC_MSG (textos em abap/README.md, seção 8.1); as chaves
"! de cada mensagem ficam na interface ZIF_PC_MSG.
CLASS zcx_pc_msg DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_abap_behv_message.
    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.
    INTERFACES zif_pc_msg.

    DATA mv_attr1 TYPE string READ-ONLY.
    DATA mv_attr2 TYPE string READ-ONLY.
    DATA mv_attr3 TYPE string READ-ONLY.
    DATA mv_attr4 TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL
        severity TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        attr1    TYPE csequence OPTIONAL
        attr2    TYPE csequence OPTIONAL
        attr3    TYPE csequence OPTIONAL
        attr4    TYPE csequence OPTIONAL.

    "! Mensagem com texto livre (até 200 caracteres; o excedente é cortado).
    "! Cada variável de mensagem T100 comporta só 50 caracteres, então o texto
    "! é distribuído em 4 blocos na mensagem 049 (&1&2&3&4).
    CLASS-METHODS texto
      IMPORTING
        iv_texto      TYPE csequence
        iv_severity   TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
      RETURNING
        VALUE(result) TYPE REF TO zcx_pc_msg.

    "! Atalho para criar mensagens de sucesso/informação.
    CLASS-METHODS sucesso
      IMPORTING
        textid        LIKE if_t100_message=>t100key
        attr1         TYPE csequence OPTIONAL
        attr2         TYPE csequence OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO zcx_pc_msg.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_pc_msg IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).

    mv_attr1 = attr1.
    mv_attr2 = attr2.
    mv_attr3 = attr3.
    mv_attr4 = attr4.

    if_abap_behv_message~m_severity = severity.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

  METHOD sucesso.
    result = NEW zcx_pc_msg( textid   = textid
                             severity = if_abap_behv_message=>severity-success
                             attr1    = attr1
                             attr2    = attr2 ).
  ENDMETHOD.

  METHOD texto.
    DATA(lv_texto) = CONV string( iv_texto ).
    DATA lt_blocos TYPE string_table.

    DO 4 TIMES.
      DATA(lv_ini) = ( sy-index - 1 ) * 50.
      IF lv_ini >= strlen( lv_texto ).
        APPEND `` TO lt_blocos.
      ELSE.
        APPEND substring( val = lv_texto off = lv_ini len = nmin( val1 = 50 val2 = strlen( lv_texto ) - lv_ini ) ) TO lt_blocos.
      ENDIF.
    ENDDO.

    result = NEW zcx_pc_msg( textid   = zif_pc_msg=>texto_livre
                             severity = iv_severity
                             attr1    = lt_blocos[ 1 ]
                             attr2    = lt_blocos[ 2 ]
                             attr3    = lt_blocos[ 3 ]
                             attr4    = lt_blocos[ 4 ] ).
  ENDMETHOD.

ENDCLASS.