"! <h1>Classe que implementa Verificação de Autorização</h1>
"!
"! <p>Centraliza as verificações usadas em <strong><em>get_global_authorizations</em></strong> dos BOs.</p>
"!
"! Objetos de autorização (criar no ADT, campo ACTVT):
"! <ul>
"!  <li><strong>ZPC_ADMIN</strong>  : 01 Criar, 02 Alterar, 06 Excluir -> Clientes e Estoque</li>
"!  <li><strong>ZPC_PEDIDO</strong> : 01 Criar, 02 Alterar, 06 Excluir, 16 Executar -> Pedidos, actions do Pedido e Reembolsos</li>
"! </ul>
"!
"! Cada operação verifica a atividade correspondente: nunca usar uma única
"! atividade genérica para criar/alterar/excluir.
"! <p>Constantes, tipos e métodos públicos são definidos na interface <strong>{@link ZIF_PC_AUTH}</strong></p>
CLASS zcl_pc_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pc_auth.

    ALIASES admin_pode_criar     FOR zif_pc_auth~admin_pode_criar.
    ALIASES admin_pode_alterar   FOR zif_pc_auth~admin_pode_alterar.
    ALIASES admin_pode_excluir   FOR zif_pc_auth~admin_pode_excluir.
    ALIASES pedido_pode_criar    FOR zif_pc_auth~pedido_pode_criar.
    ALIASES pedido_pode_alterar  FOR zif_pc_auth~pedido_pode_alterar.
    ALIASES pedido_pode_excluir  FOR zif_pc_auth~pedido_pode_excluir.
    ALIASES pedido_pode_executar FOR zif_pc_auth~pedido_pode_executar.

  PRIVATE SECTION.

    "! <p>
    "!  Verifica se o usuário possui autorização para a área administrativa
    "!  do objeto <strong>ZPC_ADMIN</strong> e valida a atividade informada no
    "!  parâmetro {@link .METH:verificar_admin.DATA:iv_actvt}.
    "! </p>
    "!
    "! <p>
    "!  Retorna <strong>abap_true</strong> quando o usuário está autorizado a
    "!  executar a ação correspondente ao ACTVT informado.
    "! </p>
    "!
    "! <p>Utilizado nas validações pelas classes locais das Classes Behavior Pool: {@link ZBP_R_PC_CLIENTE} e {@link zbp_r_pc_item}</p>
    CLASS-METHODS verificar_admin
      IMPORTING iv_actvt             TYPE c
      RETURNING VALUE(rv_autorizado) TYPE abap_boolean.

    "! <p>
    "!  Verifica se o usuário possui autorização para a área de pedidos no
    "!  objeto <strong>ZPC_PEDIDO</strong> e valida a atividade informada em
    "!  {@link .METH:verificar_pedido.DATA:iv_actvt}.
    "! </p>
    "!
    "! <p>
    "!  São aceitos valores de ACTVT para criação, alteração, exclusão e execução,
    "!  conforme as operações do processo de pedidos e reembolsos.
    "! </p>
    "!
    "! <p>Utilizado nas validações pelas classes locais das Classes Behavior Pool: {@link zbp_r_pc_pedido} e {@link zbp_r_pc_reembolso}</p>
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
