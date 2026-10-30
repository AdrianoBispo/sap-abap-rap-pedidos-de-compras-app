"! <h1>Interface para Verificação de Perfil</h1>
"! Interface onde é declarada as constantes, tipos e métodos públicos da classe {@link ZCL_PC_AUTH}
INTERFACE zif_pc_auth PUBLIC.

  CONSTANTS:
    "! Constantes que representam os valores do ACTVT, utilizadas para validação de autorização
    BEGIN OF c_actvt,
      criar    TYPE c LENGTH 2 VALUE '01',
      alterar  TYPE c LENGTH 2 VALUE '02',
      excluir  TYPE c LENGTH 2 VALUE '06',
      executar TYPE c LENGTH 2 VALUE '16',
    END OF c_actvt.

  "! Valida se o usuário tem autorização <strong>ZPC_ADMIN</strong>
  "! para criar e retorna verdadeiro ou falso.
  CLASS-METHODS admin_pode_criar
    RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

  "! Valida se o usuário tem autorização <strong>ZPC_ADMIN</strong>
  "! para alterar e retorna verdadeiro ou falso.
  CLASS-METHODS admin_pode_alterar
    RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

  "! Valida se o usuário tem autorização <strong>ZPC_ADMIN</strong>
  "! para excluir e retorna verdadeiro ou falso.
  CLASS-METHODS admin_pode_excluir
    RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

  "! Valida se o usuário tem autorização <strong>ZPC_PEDIDO</strong>
  "! para criar e retorna verdadeiro ou falso.
  CLASS-METHODS pedido_pode_criar
    RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

  "! Valida se o usuário tem autorização <strong>ZPC_PEDIDO</strong>
  "! para alterar e retorna verdadeiro ou falso.
  CLASS-METHODS pedido_pode_alterar
    RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

  "! Valida se o usuário tem autorização <strong>ZPC_PEDIDO</strong>
  "! para excluir e retorna verdadeiro ou falso.
  CLASS-METHODS pedido_pode_excluir
    RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

  "! Valida se o usuário tem autorização <strong>ZPC_PEDIDO</strong>
  "! para executar determinadas actions e retorna verdadeiro ou falso.
  CLASS-METHODS pedido_pode_executar
    RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

ENDINTERFACE.