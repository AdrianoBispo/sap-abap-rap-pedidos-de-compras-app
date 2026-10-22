"! <p class="shorttext synchronized">Pedidos de Compras - Verificação de perfil</p>
"! Constantes, tipos e métodos públicos de ZCL_PC_AUTH, que implementa esta interface.
INTERFACE zif_pc_auth PUBLIC.

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

ENDINTERFACE.