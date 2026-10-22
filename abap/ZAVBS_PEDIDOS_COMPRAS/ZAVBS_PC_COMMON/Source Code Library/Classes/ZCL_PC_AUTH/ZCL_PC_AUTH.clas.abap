"! <p class="shorttext synchronized">Pedidos de Compras - Verificação de perfil</p>
"! Centraliza as verificações usadas em get_global_authorizations dos BOs.
"!
"! Objetos de autorização (criar no ADT, campo ACTVT):
"!  - ZPC_ADMIN  : 01 criar, 02 alterar, 06 excluir -> Clientes e Estoque
"!  - ZPC_PEDIDO : 01 criar, 02 alterar, 06 excluir, 16 executar -> Pedidos,
"!                 actions do pedido e Reembolsos
"! Os objetos são atribuídos às IAM Apps (aba Authorizations) e as restrições
"! são mantidas nas Business Roles ZPC_BR_ADMIN / ZPC_BR_COMUM.
"!
"! Cada operação verifica a atividade correspondente: nunca usar uma única
"! atividade genérica para criar/alterar/excluir.
"! Constantes, tipos e métodos públicos: interface ZIF_PC_AUTH.
CLASS zcl_pc_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pc_auth.

    ALIASES admin_pode_criar FOR zif_pc_auth~admin_pode_criar.
    ALIASES admin_pode_alterar FOR zif_pc_auth~admin_pode_alterar.
    ALIASES admin_pode_excluir FOR zif_pc_auth~admin_pode_excluir.
    ALIASES pedido_pode_criar FOR zif_pc_auth~pedido_pode_criar.
    ALIASES pedido_pode_alterar FOR zif_pc_auth~pedido_pode_alterar.
    ALIASES pedido_pode_excluir FOR zif_pc_auth~pedido_pode_excluir.
    ALIASES pedido_pode_executar FOR zif_pc_auth~pedido_pode_executar.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS verificar_admin
      IMPORTING iv_actvt             TYPE c
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

    CLASS-METHODS verificar_pedido
      IMPORTING iv_actvt             TYPE c
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.
ENDCLASS.



CLASS zcl_pc_auth IMPLEMENTATION.

  METHOD verificar_admin.
    IF zif_pc_constants=>c_modo_trial = abap_true.
      rv_autorizado = abap_true.
      RETURN.
    ENDIF.

    AUTHORITY-CHECK OBJECT 'ZPC_ADMIN'
      ID 'ACTVT' FIELD iv_actvt.
    rv_autorizado = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD verificar_pedido.
    IF zif_pc_constants=>c_modo_trial = abap_true.
      rv_autorizado = abap_true.
      RETURN.
    ENDIF.

    AUTHORITY-CHECK OBJECT 'ZPC_PEDIDO'
      ID 'ACTVT' FIELD iv_actvt.
    rv_autorizado = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD zif_pc_auth~admin_pode_criar.
    rv_autorizado = verificar_admin( zif_pc_auth=>c_actvt-criar ).
  ENDMETHOD.

  METHOD zif_pc_auth~admin_pode_alterar.
    rv_autorizado = verificar_admin( zif_pc_auth=>c_actvt-alterar ).
  ENDMETHOD.

  METHOD zif_pc_auth~admin_pode_excluir.
    rv_autorizado = verificar_admin( zif_pc_auth=>c_actvt-excluir ).
  ENDMETHOD.

  METHOD zif_pc_auth~pedido_pode_criar.
    rv_autorizado = verificar_pedido( zif_pc_auth=>c_actvt-criar ).
  ENDMETHOD.

  METHOD zif_pc_auth~pedido_pode_alterar.
    rv_autorizado = verificar_pedido( zif_pc_auth=>c_actvt-alterar ).
  ENDMETHOD.

  METHOD zif_pc_auth~pedido_pode_excluir.
    rv_autorizado = verificar_pedido( zif_pc_auth=>c_actvt-excluir ).
  ENDMETHOD.

  METHOD zif_pc_auth~pedido_pode_executar.
    rv_autorizado = verificar_pedido( zif_pc_auth=>c_actvt-executar ).
  ENDMETHOD.

ENDCLASS.
