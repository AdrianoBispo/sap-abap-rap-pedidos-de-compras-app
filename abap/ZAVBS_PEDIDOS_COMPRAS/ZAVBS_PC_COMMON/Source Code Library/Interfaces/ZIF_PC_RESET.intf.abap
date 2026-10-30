"! Interface onde é declarada as constantes, tipos e métodos públicos da classe {@link ZCL_PC_RESET}
INTERFACE zif_pc_reset PUBLIC.

  TYPES:
    BEGIN OF ty_resultado,
      tabela    TYPE string,
      apagados  TYPE i,
    END OF ty_resultado.

  TYPES tt_resultado TYPE STANDARD TABLE OF ty_resultado WITH EMPTY KEY.

  "! <p>Apaga os dados e devolve a quantidade apagada por tabela.</p>
  "! <p>OBS: Em ambiente que não é de demonstração não apaga nada.<p>
  CLASS-METHODS resetar
    EXPORTING et_resultado TYPE tt_resultado
              ev_executado TYPE abap_boolean.

ENDINTERFACE.