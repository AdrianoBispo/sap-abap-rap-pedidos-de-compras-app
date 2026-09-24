"! <p class="shorttext synchronized">Pedidos de Compras - Mensagens RAP (T100)</p>
"! Classe de mensagens usada em todos os BOs. Os textos ficam na
"! Message Class ZPC_MSG (ver zpc_msg.msag.csv).
CLASS zcx_pc_msg DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_abap_behv_message.
    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.

    DATA mv_attr1 TYPE string READ-ONLY.
    DATA mv_attr2 TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL
        severity TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        attr1    TYPE csequence OPTIONAL
        attr2    TYPE csequence OPTIONAL.

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

ENDCLASS.
