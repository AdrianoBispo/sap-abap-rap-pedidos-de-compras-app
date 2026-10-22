"! <p class="shorttext synchronized">Pedidos de Compras - Reset dos dados do banco</p>
"! Constantes, tipos e métodos públicos de ZCL_PC_RESET, que implementa esta interface.
INTERFACE zif_pc_reset PUBLIC.

  TYPES:
    BEGIN OF ty_resultado,
      tabela    TYPE string,
      apagados  TYPE i,
    END OF ty_resultado.
  TYPES tt_resultado TYPE STANDARD TABLE OF ty_resultado WITH EMPTY KEY.

  "! Apaga os dados e confirma (COMMIT WORK). Devolve a quantidade apagada
  "! por tabela. Em ambiente que não é de demonstração não apaga nada.
  CLASS-METHODS resetar
    EXPORTING et_resultado TYPE tt_resultado
              ev_executado TYPE abap_boolean.

ENDINTERFACE.