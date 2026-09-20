"! <p class="shorttext synchronized">Pedidos de Compras - Verificação de perfil</p>
"! Centraliza as verificações de autorização usadas no método
"! get_global_authorizations dos BOs.
"!
"! Objetos de autorização (criar no ADT, campo ACTVT):
"!  - ZPC_ADMIN  : ACTVT 01/02/06 -> manutenção de Clientes e Estoque
"!  - ZPC_PEDIDO : ACTVT 01/02/16 -> criação/edição e ações de Pedidos
"! Os objetos são atribuídos às IAM Apps (aba Authorizations) e as
"! restrições são mantidas nas Business Roles ZPC_BR_ADMIN / ZPC_BR_COMUM.
CLASS zcl_pc_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Usuário pode criar/editar/excluir/inativar clientes e itens.
    CLASS-METHODS is_admin
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

    "! Usuário pode criar/editar pedidos e executar suas ações.
    CLASS-METHODS pode_operar_pedidos
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_pc_auth IMPLEMENTATION.

  METHOD is_admin.
    IF zif_pc_constants=>c_modo_trial = abap_true.
      rv_autorizado = abap_true.
      RETURN.
    ENDIF.

    AUTHORITY-CHECK OBJECT 'ZPC_ADMIN'
      ID 'ACTVT' FIELD '02'.
    rv_autorizado = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD pode_operar_pedidos.
    IF zif_pc_constants=>c_modo_trial = abap_true.
      rv_autorizado = abap_true.
      RETURN.
    ENDIF.

    AUTHORITY-CHECK OBJECT 'ZPC_PEDIDO'
      ID 'ACTVT' FIELD '16'.
    rv_autorizado = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

ENDCLASS.
