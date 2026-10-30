*"* Test Classes da classe ZCL_PC_AUTH

"! O comportamento depende de <strong>ZIF_PC_CONSTANTS=>C_MODO_TRIAL</strong>: cada classe abaixo
"! só verifica o modo em que o sistema está e retorna sem asserções no outro.
"! Modo trial (BTP Trial, abap_true): todas as operações são liberadas
CLASS ltcl_modo_trial DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS libera_todas_as_operacoes FOR TESTING.
ENDCLASS.


CLASS ltcl_modo_trial IMPLEMENTATION.

  METHOD libera_todas_as_operacoes.
    IF zif_pc_constants=>c_modo_trial = abap_false.
      RETURN. " AUTHORITY-CHECK ativo: coberto por ltcl_authority_check
    ENDIF.

    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>admin_pode_criar( )     msg = 'ZPC_ADMIN 01' ).
    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>admin_pode_alterar( )   msg = 'ZPC_ADMIN 02' ).
    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>admin_pode_excluir( )   msg = 'ZPC_ADMIN 06' ).
    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>pedido_pode_criar( )    msg = 'ZPC_PEDIDO 01' ).
    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>pedido_pode_alterar( )  msg = 'ZPC_PEDIDO 02' ).
    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>pedido_pode_excluir( )  msg = 'ZPC_PEDIDO 06' ).
    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>pedido_pode_executar( ) msg = 'ZPC_PEDIDO 16' ).
  ENDMETHOD.

ENDCLASS.


"! Modo real (On-Premise ou BTP com Business Roles, abap_false): o AUTHORITY-CHECK
"! é testado com CL_AUNIT_AUTHORITY_CHECK, sem depender das roles de quem executa.
"! Cada método verifica só a atividade (ACTVT) do seu objeto.
CLASS ltcl_authority_check DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Restringe o usuário do teste às atividades informadas de um objeto
    "! (sem objeto: nenhuma autorização).
    METHODS restringir
      IMPORTING iv_objeto TYPE csequence OPTIONAL
                it_actvt  TYPE string_table OPTIONAL.

    METHODS admin_somente_criar      FOR TESTING.
    METHODS admin_completo           FOR TESTING.
    METHODS pedido_sem_executar      FOR TESTING.
    METHODS pedido_somente_executar  FOR TESTING.
    METHODS sem_autorizacao          FOR TESTING.
ENDCLASS.


CLASS ltcl_authority_check IMPLEMENTATION.

  METHOD restringir.

    DATA(lo_ctrl) = cl_aunit_authority_check=>get_controller( ).

    IF iv_objeto IS INITIAL.
      lo_ctrl->restrict_authorizations_to( cl_aunit_authority_check=>create_auth_object_set( VALUE #( ) ) ).
      RETURN.
    ENDIF.

    DATA(lo_role) = cl_aunit_authority_check=>create_auth_object_set(
      VALUE #( ( role_authorizations = VALUE #(
                   ( object         = iv_objeto
                     authorizations = VALUE #( ( VALUE #( ( fieldname   = 'ACTVT'
                                                            fieldvalues = VALUE #( FOR a IN it_actvt
                                                                                   ( lower_value = a ) ) ) ) ) ) ) ) ) ) ).
    lo_ctrl->restrict_authorizations_to( lo_role ).
  ENDMETHOD.

  METHOD admin_somente_criar.
    CHECK zif_pc_constants=>c_modo_trial = abap_false.

    restringir( iv_objeto = zif_pc_constants=>c_auth-objeto_admin
                it_actvt  = VALUE #( ( `01` ) ) ).

    cl_abap_unit_assert=>assert_true(  act = zcl_pc_auth=>admin_pode_criar( )   msg = '01 autoriza criar' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>admin_pode_alterar( ) msg = '01 não autoriza alterar' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>admin_pode_excluir( ) msg = '01 não autoriza excluir' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>pedido_pode_criar( )
                                       msg = 'ZPC_ADMIN não concede ZPC_PEDIDO' ).
  ENDMETHOD.

  METHOD admin_completo.
    CHECK zif_pc_constants=>c_modo_trial = abap_false.

    restringir( iv_objeto = zif_pc_constants=>c_auth-objeto_admin
                it_actvt  = VALUE #( ( `01` ) ( `02` ) ( `06` ) ) ).

    cl_abap_unit_assert=>assert_true(  act = zcl_pc_auth=>admin_pode_criar( )   msg = 'Criar' ).
    cl_abap_unit_assert=>assert_true(  act = zcl_pc_auth=>admin_pode_alterar( ) msg = 'Alterar' ).
    cl_abap_unit_assert=>assert_true(  act = zcl_pc_auth=>admin_pode_excluir( ) msg = 'Excluir' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>pedido_pode_executar( )
                                       msg = 'Administrador de cadastro não executa ações do pedido' ).
  ENDMETHOD.

  METHOD pedido_sem_executar.
    " Perfil comum: cria e altera pedidos, mas não paga, aprova nem cancela
    CHECK zif_pc_constants=>c_modo_trial = abap_false.

    restringir( iv_objeto = zif_pc_constants=>c_auth-objeto_pedido
                it_actvt  = VALUE #( ( `01` ) ( `02` ) ) ).

    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>pedido_pode_criar( )    msg = 'Criar pedido' ).
    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>pedido_pode_alterar( )  msg = 'Alterar pedido' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>pedido_pode_excluir( )  msg = 'Sem 06' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>pedido_pode_executar( ) msg = 'Sem 16' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>admin_pode_criar( )
                                       msg = 'ZPC_PEDIDO não concede ZPC_ADMIN' ).
  ENDMETHOD.

  METHOD pedido_somente_executar.
    CHECK zif_pc_constants=>c_modo_trial = abap_false.

    restringir( iv_objeto = zif_pc_constants=>c_auth-objeto_pedido
                it_actvt  = VALUE #( ( `16` ) ) ).

    cl_abap_unit_assert=>assert_true( act = zcl_pc_auth=>pedido_pode_executar( ) msg = '16 autoriza executar' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>pedido_pode_criar( ) msg = '16 não autoriza criar' ).
  ENDMETHOD.

  METHOD sem_autorizacao.
    CHECK zif_pc_constants=>c_modo_trial = abap_false.

    restringir( ).

    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>admin_pode_criar( )     msg = 'ZPC_ADMIN 01' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>admin_pode_alterar( )   msg = 'ZPC_ADMIN 02' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>admin_pode_excluir( )   msg = 'ZPC_ADMIN 06' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>pedido_pode_criar( )    msg = 'ZPC_PEDIDO 01' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>pedido_pode_alterar( )  msg = 'ZPC_PEDIDO 02' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>pedido_pode_excluir( )  msg = 'ZPC_PEDIDO 06' ).
    cl_abap_unit_assert=>assert_false( act = zcl_pc_auth=>pedido_pode_executar( ) msg = 'ZPC_PEDIDO 16' ).
  ENDMETHOD.

ENDCLASS.
