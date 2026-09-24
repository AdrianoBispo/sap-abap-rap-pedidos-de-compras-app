"! <p class="shorttext synchronized">Pedidos de Compras - Verificação de perfil</p>
"! Centraliza as verificações usadas em get_global_authorizations dos BOs.
"!
"! Objetos de autorização (criar no ADT, campo ACTVT):
"!  - ZPC_ADMIN  : 01 criar, 02 alterar, 06 excluir -> Clientes e Estoque
"!  - ZPC_PEDIDO : 01 criar, 02 alterar, 16 executar -> Pedidos e suas actions
"! Os objetos são atribuídos às IAM Apps (aba Authorizations) e as restrições
"! são mantidas nas Business Roles ZPC_BR_ADMIN / ZPC_BR_COMUM.
"!
"! Cada operação verifica a atividade correspondente: nunca usar uma única
"! atividade genérica para criar/alterar/excluir.
CLASS zcl_pc_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF c_actvt,
        criar     TYPE c LENGTH 2 VALUE '01',
        alterar   TYPE c LENGTH 2 VALUE '02',
        excluir   TYPE c LENGTH 2 VALUE '06',
        executar  TYPE c LENGTH 2 VALUE '16',
      END OF c_actvt.

    "! Administração de clientes e itens de estoque (ZPC_ADMIN).
    CLASS-METHODS admin_pode_criar
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.
    CLASS-METHODS admin_pode_alterar
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.
    CLASS-METHODS admin_pode_excluir
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

    "! Operação de pedidos (ZPC_PEDIDO).
    CLASS-METHODS pedido_pode_criar
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.
    CLASS-METHODS pedido_pode_alterar
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.
    CLASS-METHODS pedido_pode_excluir
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.
    CLASS-METHODS pedido_pode_executar
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

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


  METHOD admin_pode_criar.
    rv_autorizado = verificar_admin( c_actvt-criar ).
  ENDMETHOD.

  METHOD admin_pode_alterar.
    rv_autorizado = verificar_admin( c_actvt-alterar ).
  ENDMETHOD.

  METHOD admin_pode_excluir.
    rv_autorizado = verificar_admin( c_actvt-excluir ).
  ENDMETHOD.

  METHOD pedido_pode_criar.
    rv_autorizado = verificar_pedido( c_actvt-criar ).
  ENDMETHOD.

  METHOD pedido_pode_alterar.
    rv_autorizado = verificar_pedido( c_actvt-alterar ).
  ENDMETHOD.

  METHOD pedido_pode_excluir.
    rv_autorizado = verificar_pedido( c_actvt-excluir ).
  ENDMETHOD.

  METHOD pedido_pode_executar.
    rv_autorizado = verificar_pedido( c_actvt-executar ).
  ENDMETHOD.

ENDCLASS.
