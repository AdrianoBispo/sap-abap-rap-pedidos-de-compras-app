"! <h1>Classe para Tratamento de Erros das Apps RAP</h1>
"! Classe de mensagens usada em todos os BOs. Os textos ficam na
"! classe de mensagens <strong>ZPC_MSG</strong>. As chaves de cada mensagem,
"! os atributos MV_ATTR1 a MV_ATTR4 e os métodos TEXTO e SUCESSO
"! ficam na interface {@link ZIF_PC_MSG}.
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

    ALIASES mv_attr1 FOR zif_pc_msg~mv_attr1.
    ALIASES mv_attr2 FOR zif_pc_msg~mv_attr2.
    ALIASES mv_attr3 FOR zif_pc_msg~mv_attr3.
    ALIASES mv_attr4 FOR zif_pc_msg~mv_attr4.
    ALIASES texto FOR zif_pc_msg~texto.
    ALIASES sucesso FOR zif_pc_msg~sucesso.

    "! Construtor da classe de exceção para mensagens de erros
    "! @parameter textid | Chave T100 da mensagem. Opcional; se vazia, usa a mensagem padrão.
    "! @parameter previous | Exceção anterior que originou esta mensagem. Opcional.
    "! @parameter severity | Severidade da mensagem exibida ao usuário (erro, aviso, sucesso etc.).
    "! @parameter attr1 | Primeiro atributo dinâmico da mensagem. Opcional.
    "! @parameter attr2 | Segundo atributo dinâmico da mensagem. Opcional.
    "! @parameter attr3 | Terceiro atributo dinâmico da mensagem. Opcional.
    "! @parameter attr4 | Quarto atributo dinâmico da mensagem. Opcional.
    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL
        severity TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        attr1    TYPE csequence OPTIONAL
        attr2    TYPE csequence OPTIONAL
        attr3    TYPE csequence OPTIONAL
        attr4    TYPE csequence OPTIONAL.

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

  METHOD zif_pc_msg~sucesso.
    result = NEW zcx_pc_msg( textid   = textid
                             severity = if_abap_behv_message=>severity-success
                             attr1    = attr1
                             attr2    = attr2 ).
  ENDMETHOD.

  METHOD zif_pc_msg~texto.
    DATA(lv_texto) = CONV string( iv_texto ).
    DATA lt_blocos TYPE string_table.

    DO 4 TIMES.
      DATA(lv_ini) = ( sy-index - 1 ) * 50.

      IF lv_ini >= strlen( lv_texto ).
        APPEND `` TO lt_blocos.

      ELSE.
        APPEND substring( val = lv_texto
                          off = lv_ini
                          len = nmin( val1 = 50
                                      val2 = strlen( lv_texto ) - lv_ini ) ) TO lt_blocos.

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