*"* Local Types da behavior pool ZBP_R_PC_CLIENTE

"! Handler da entidade Cliente (root)
CLASS lhc_cliente DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_area,
        cpf         TYPE string VALUE `VALIDAR_CPF`,
        obrigatorio TYPE string VALUE `VALIDAR_OBRIGATORIOS`,
        email       TYPE string VALUE `VALIDAR_EMAIL`,
        telefone    TYPE string VALUE `VALIDAR_TELEFONE`,
        nascimento  TYPE string VALUE `VALIDAR_NASCIMENTO`,
        genero      TYPE string VALUE `VALIDAR_GENERO`,
        foto        TYPE string VALUE `VALIDAR_FOTO`,
      END OF c_area.

    TYPES tt_uuid TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED EARLY zr_pc_cliente.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED EARLY zr_pc_cliente.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Cliente RESULT result.

    "! Importação em massa por planilha (.xlsx/.csv): cria clientes ativos, cada
    "! um com o endereço principal. Tudo ou nada: qualquer erro cancela a importação.
    METHODS ImportarPlanilha FOR MODIFY
      IMPORTING keys FOR ACTION Cliente~ImportarPlanilha.

    "! Reporta os erros da importação (primeiro o resumo) e falha a action,
    "! o que descarta qualquer cliente já criado no buffer.
    METHODS falhar_importacao
      IMPORTING it_erros     TYPE string_table
                iv_cid       TYPE abp_behv_cid
      CHANGING  cs_failed    TYPE ty_failed
                cs_reported  TYPE ty_reported.

    "! "Linha N: " a partir do %cid (CLI ou END seguido do número da linha).
    METHODS linha_do_cid
      IMPORTING iv_cid          TYPE csequence
      RETURNING VALUE(rv_texto) TYPE string.

    "! Endereco usa authorization master(global) (ver comentário na BDEF):
    "! mesma regra de negócio de Cliente (ZPC_ADMIN via ZCL_PC_AUTH).
    METHODS get_global_auth_endereco FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Endereco RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Cliente RESULT result.

    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Cliente.

    METHODS DefinirValoresIniciais FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Cliente~DefinirValoresIniciais.

    METHODS NormalizarDados FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Cliente~NormalizarDados.

    METHODS ValidarCpf FOR VALIDATE ON SAVE
      IMPORTING keys FOR Cliente~ValidarCpf.

    METHODS ValidarDadosObrigatorios FOR VALIDATE ON SAVE
      IMPORTING keys FOR Cliente~ValidarDadosObrigatorios.

    METHODS ValidarEmail FOR VALIDATE ON SAVE
      IMPORTING keys FOR Cliente~ValidarEmail.

    METHODS ValidarTelefone FOR VALIDATE ON SAVE
      IMPORTING keys FOR Cliente~ValidarTelefone.

    METHODS ValidarDataNascimento FOR VALIDATE ON SAVE
      IMPORTING keys FOR Cliente~ValidarDataNascimento.

    METHODS ValidarGenero FOR VALIDATE ON SAVE
      IMPORTING keys FOR Cliente~ValidarGenero.

    METHODS ValidarFoto FOR VALIDATE ON SAVE
      IMPORTING keys FOR Cliente~ValidarFoto.

    "! Clientes (entre os informados) que possuem pedido ativo ou em draft.
    METHODS clientes_com_pedido
      IMPORTING it_clientes     TYPE tt_uuid
      RETURNING VALUE(rt_com_pedido) TYPE tt_uuid.

    METHODS msg
      IMPORTING textid        LIKE if_t100_message=>t100key
                attr1         TYPE csequence OPTIONAL
      RETURNING VALUE(ro_msg) TYPE REF TO if_abap_behv_message.
ENDCLASS.


CLASS lhc_cliente IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Cada operação verifica sua própria atividade (ACTVT)
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = COND #( WHEN zcl_pc_auth=>admin_pode_criar( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = COND #( WHEN zcl_pc_auth=>admin_pode_alterar( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = COND #( WHEN zcl_pc_auth=>admin_pode_excluir( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-Edit = if_abap_behv=>mk-on.
      result-%action-Edit = COND #( WHEN zcl_pc_auth=>admin_pode_alterar( ) = abap_true
                                    THEN if_abap_behv=>auth-allowed
                                    ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-ImportarPlanilha = if_abap_behv=>mk-on.
      result-%action-ImportarPlanilha = COND #( WHEN zcl_pc_auth=>admin_pode_criar( ) = abap_true
                                                THEN if_abap_behv=>auth-allowed
                                                ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.


  METHOD get_global_auth_endereco.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = COND #( WHEN zcl_pc_auth=>admin_pode_alterar( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = COND #( WHEN zcl_pc_auth=>admin_pode_excluir( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-DefinirEnderecoPrincipal = if_abap_behv=>mk-on.
      result-%action-DefinirEnderecoPrincipal = COND #( WHEN zcl_pc_auth=>admin_pode_alterar( ) = abap_true
                                                         THEN if_abap_behv=>auth-allowed
                                                         ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    DATA lt_ids TYPE tt_uuid.
    LOOP AT keys INTO DATA(ls_k).
      INSERT ls_k-ClienteUUID INTO TABLE lt_ids.
    ENDLOOP.

    DATA(lt_com_pedido) = clientes_com_pedido( lt_ids ).

    result = VALUE #( FOR k IN keys
                      ( %tky    = k-%tky
                        %delete = COND #( WHEN line_exists( lt_com_pedido[ table_line = k-ClienteUUID ] )
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.


  METHOD precheck_delete.
    DATA lt_ids TYPE tt_uuid.
    LOOP AT keys INTO DATA(ls_k).
      INSERT ls_k-ClienteUUID INTO TABLE lt_ids.
    ENDLOOP.

    DATA(lt_com_pedido) = clientes_com_pedido( lt_ids ).

    LOOP AT keys INTO DATA(ls_key).
      IF line_exists( lt_com_pedido[ table_line = ls_key-ClienteUUID ] ).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = msg( zcx_pc_msg=>cliente_com_pedido ) ) TO reported-cliente.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD clientes_com_pedido.
    CHECK it_clientes IS NOT INITIAL.

    " Pedidos ativos
    SELECT ClienteUUID
      FROM zr_pc_pedido
      FOR ALL ENTRIES IN @it_clientes
      WHERE ClienteUUID = @it_clientes-table_line
      INTO TABLE @DATA(lt_ativos).

    " Pedidos ainda em draft (ainda não ativados)
    SELECT clienteuuid
      FROM zta_pc_pedido_d
      FOR ALL ENTRIES IN @it_clientes
      WHERE clienteuuid = @it_clientes-table_line
      INTO TABLE @DATA(lt_drafts).

    LOOP AT lt_ativos INTO DATA(ls_ativo).
      INSERT ls_ativo-ClienteUUID INTO TABLE rt_com_pedido.
    ENDLOOP.
    LOOP AT lt_drafts INTO DATA(ls_draft).
      INSERT ls_draft-clienteuuid INTO TABLE rt_com_pedido.
    ENDLOOP.
  ENDMETHOD.


  METHOD DefinirValoresIniciais.
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        FIELDS ( ClienteAtivo ScoreCliente )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_clientes).

    " Novo cliente nasce ativo, com um Score inicial sorteado (0-100)
    DELETE lt_clientes WHERE ClienteAtivo = abap_true.
    CHECK lt_clientes IS NOT INITIAL.

    DATA(lo_random) = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                                  min  = 0
                                                  max  = 100 ).

    MODIFY ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        UPDATE FIELDS ( ClienteAtivo ScoreCliente )
        WITH VALUE #( FOR c IN lt_clientes
                      ( %tky         = c-%tky
                        ClienteAtivo = abap_true
                        ScoreCliente = lo_random->get_next( ) ) )
      REPORTED DATA(ls_rep_cliente0_all).

    LOOP AT ls_rep_cliente0_all-cliente INTO DATA(ls_rep_cliente0) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_cliente0 ) TO reported-cliente.
    ENDLOOP.
  ENDMETHOD.


  METHOD NormalizarDados.
    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_cliente\\Cliente.

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        FIELDS ( Cpf Telefone Email )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_clientes).

    LOOP AT lt_clientes INTO DATA(ls_cliente).
      DATA(lv_cpf)      = CONV zr_pc_cliente-Cpf( zcl_pc_util=>somente_digitos( ls_cliente-Cpf ) ).
      DATA(lv_telefone) = CONV zr_pc_cliente-Telefone( zcl_pc_util=>somente_digitos( ls_cliente-Telefone ) ).
      DATA(lv_email)    = CONV zr_pc_cliente-Email( condense( to_lower( ls_cliente-Email ) ) ).

      IF lv_cpf <> ls_cliente-Cpf OR lv_telefone <> ls_cliente-Telefone OR lv_email <> ls_cliente-Email.
        APPEND VALUE #( %tky     = ls_cliente-%tky
                        Cpf      = lv_cpf
                        Telefone = lv_telefone
                        Email    = lv_email
                        %control = VALUE #( Cpf      = if_abap_behv=>mk-on
                                            Telefone = if_abap_behv=>mk-on
                                            Email    = if_abap_behv=>mk-on ) ) TO lt_update.
      ENDIF.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente UPDATE FROM lt_update
      REPORTED DATA(ls_rep_cliente1_all).

    LOOP AT ls_rep_cliente1_all-cliente INTO DATA(ls_rep_cliente1) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_cliente1 ) TO reported-cliente.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarCpf.
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        FIELDS ( Cpf )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_clientes).

    LOOP AT lt_clientes INTO DATA(ls_cliente).
      APPEND VALUE #( %tky        = ls_cliente-%tky
                      %state_area = c_area-cpf ) TO reported-cliente.

      IF ls_cliente-Cpf IS INITIAL.
        CONTINUE. " tratado em ValidarDadosObrigatorios
      ENDIF.

      IF zcl_pc_util=>validar_cpf( ls_cliente-Cpf ) = abap_false.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky        = ls_cliente-%tky
                        %state_area = c_area-cpf
                        %msg        = msg( zcx_pc_msg=>cliente_cpf_invalido )
                        %element-Cpf = if_abap_behv=>mk-on ) TO reported-cliente.
        CONTINUE.
      ENDIF.

      " Unicidade: nenhum outro cliente ativo com o mesmo CPF
      SELECT SINGLE @abap_true
        FROM zta_pc_cliente
        WHERE cpf          =  @ls_cliente-Cpf
          AND cliente_uuid <> @ls_cliente-ClienteUUID
        INTO @DATA(lv_existe).

      IF lv_existe = abap_true.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky        = ls_cliente-%tky
                        %state_area = c_area-cpf
                        %msg        = msg( zcx_pc_msg=>cliente_cpf_duplicado )
                        %element-Cpf = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
      CLEAR lv_existe.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarDadosObrigatorios.
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        FIELDS ( Cpf Nome Email Telefone DataNascimento )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_clientes).

    LOOP AT lt_clientes INTO DATA(ls_cliente).
      APPEND VALUE #( %tky        = ls_cliente-%tky
                      %state_area = c_area-obrigatorio ) TO reported-cliente.

      IF ls_cliente-Cpf IS INITIAL.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky = ls_cliente-%tky %state_area = c_area-obrigatorio
                        %msg = msg( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'CPF' )
                        %element-Cpf = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
      IF ls_cliente-Nome IS INITIAL.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky = ls_cliente-%tky %state_area = c_area-obrigatorio
                        %msg = msg( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Nome' )
                        %element-Nome = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
      IF ls_cliente-Email IS INITIAL.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky = ls_cliente-%tky %state_area = c_area-obrigatorio
                        %msg = msg( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'E-mail' )
                        %element-Email = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
      IF ls_cliente-Telefone IS INITIAL.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky = ls_cliente-%tky %state_area = c_area-obrigatorio
                        %msg = msg( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Telefone' )
                        %element-Telefone = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
      IF ls_cliente-DataNascimento IS INITIAL.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky = ls_cliente-%tky %state_area = c_area-obrigatorio
                        %msg = msg( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Data de nascimento' )
                        %element-DataNascimento = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarEmail.
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        FIELDS ( Email )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_clientes).

    LOOP AT lt_clientes INTO DATA(ls_cliente).
      APPEND VALUE #( %tky        = ls_cliente-%tky
                      %state_area = c_area-email ) TO reported-cliente.

      IF ls_cliente-Email IS NOT INITIAL
         AND zcl_pc_util=>validar_email( ls_cliente-Email ) = abap_false.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky           = ls_cliente-%tky
                        %state_area    = c_area-email
                        %msg           = msg( zcx_pc_msg=>email_invalido )
                        %element-Email = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarTelefone.
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        FIELDS ( Telefone )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_clientes).

    LOOP AT lt_clientes INTO DATA(ls_cliente).
      APPEND VALUE #( %tky        = ls_cliente-%tky
                      %state_area = c_area-telefone ) TO reported-cliente.

      CHECK ls_cliente-Telefone IS NOT INITIAL.

      DATA(lv_tel) = zcl_pc_util=>somente_digitos( ls_cliente-Telefone ).
      IF strlen( lv_tel ) < 10 OR strlen( lv_tel ) > 11.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky              = ls_cliente-%tky
                        %state_area       = c_area-telefone
                        %msg              = msg( zcx_pc_msg=>telefone_invalido )
                        %element-Telefone = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarDataNascimento.
    DATA(lv_hoje) = cl_abap_context_info=>get_system_date( ).

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        FIELDS ( DataNascimento )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_clientes).

    LOOP AT lt_clientes INTO DATA(ls_cliente).
      APPEND VALUE #( %tky        = ls_cliente-%tky
                      %state_area = c_area-nascimento ) TO reported-cliente.

      IF ls_cliente-DataNascimento IS NOT INITIAL AND ls_cliente-DataNascimento > lv_hoje.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky                    = ls_cliente-%tky
                        %state_area             = c_area-nascimento
                        %msg                    = msg( zcx_pc_msg=>data_nascimento_futura )
                        %element-DataNascimento = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarGenero.
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        FIELDS ( Genero )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_clientes).

    LOOP AT lt_clientes INTO DATA(ls_cliente).
      APPEND VALUE #( %tky        = ls_cliente-%tky
                      %state_area = c_area-genero ) TO reported-cliente.

      CHECK ls_cliente-Genero IS NOT INITIAL.

      SELECT SINGLE @abap_true
        FROM zr_pc_codelist
        WHERE Lista  = @zif_pc_constants=>c_codelist-genero
          AND Codigo = @ls_cliente-Genero
        INTO @DATA(lv_ok).

      IF lv_ok = abap_false.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky            = ls_cliente-%tky
                        %state_area     = c_area-genero
                        %msg            = msg( textid = zcx_pc_msg=>valor_invalido attr1 = 'Gênero' )
                        %element-Genero = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
      CLEAR lv_ok.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarFoto.
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        FIELDS ( FotoCliente FotoMimeType FotoFileName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_clientes).

    LOOP AT lt_clientes INTO DATA(ls_cliente).
      APPEND VALUE #( %tky        = ls_cliente-%tky
                      %state_area = c_area-foto ) TO reported-cliente.

      IF zcl_pc_util=>validar_imagem( iv_conteudo     = ls_cliente-FotoCliente
                                      iv_mime_type    = ls_cliente-FotoMimeType
                                      iv_nome_arquivo = ls_cliente-FotoFileName ) = abap_false.
        APPEND VALUE #( %tky = ls_cliente-%tky ) TO failed-cliente.
        APPEND VALUE #( %tky                 = ls_cliente-%tky
                        %state_area          = c_area-foto
                        %msg                 = msg( zcx_pc_msg=>foto_formato_invalido )
                        %element-FotoCliente = if_abap_behv=>mk-on ) TO reported-cliente.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ImportarPlanilha.
    TYPES:
      BEGIN OF ty_cliente,
        linha       TYPE i,
        cpf         TYPE zr_pc_cliente-Cpf,
        nome        TYPE zr_pc_cliente-Nome,
        email       TYPE zr_pc_cliente-Email,
        telefone    TYPE zr_pc_cliente-Telefone,
        genero      TYPE zr_pc_cliente-Genero,
        nascimento  TYPE zr_pc_cliente-DataNascimento,
        cep         TYPE zr_pc_endereco-Cep,
        numero      TYPE zr_pc_endereco-Numero,
        complemento TYPE zr_pc_endereco-Complemento,
      END OF ty_cliente.

    CONSTANTS:
      BEGIN OF c_col,
        cpf         TYPE string VALUE `CPF`,
        nome        TYPE string VALUE `Nome`,
        email       TYPE string VALUE `E-mail`,
        telefone    TYPE string VALUE `Telefone`,
        genero      TYPE string VALUE `Gênero`,
        nascimento  TYPE string VALUE `Data de nascimento`,
        cep         TYPE string VALUE `CEP`,
        numero      TYPE string VALUE `Número`,
        complemento TYPE string VALUE `Complemento`,
      END OF c_col.

    DATA lt_colunas TYPE zcl_pc_planilha=>tt_colunas.
    DATA lt_erros   TYPE string_table.
    DATA lt_cli     TYPE STANDARD TABLE OF ty_cliente WITH EMPTY KEY.
    DATA lt_cpf_arq TYPE SORTED TABLE OF zr_pc_cliente-Cpf WITH UNIQUE KEY table_line.

    lt_colunas = VALUE #(
      ( campo = c_col-cpf        obrigatoria = abap_true )
      ( campo = c_col-nome       sinonimos = `NOMECOMPLETO|NOMEDOCLIENTE`                obrigatoria = abap_true )
      ( campo = c_col-email      sinonimos = `EMAILDOCLIENTE`                            obrigatoria = abap_true )
      ( campo = c_col-telefone   sinonimos = `CELULAR|FONE|TELEFONECELULAR`              obrigatoria = abap_true )
      ( campo = c_col-genero     sinonimos = `SEXO` )
      ( campo = c_col-nascimento sinonimos = `NASCIMENTO|DATANASC|DTNASCIMENTO`          obrigatoria = abap_true )
      ( campo = c_col-cep        obrigatoria = abap_true )
      ( campo = c_col-numero     sinonimos = `NUM|NRO|NUMEROENDERECO`                    obrigatoria = abap_true )
      ( campo = c_col-complemento ) ).

    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lt_erros, lt_cli, lt_cpf_arq.

      IF zcl_pc_auth=>admin_pode_criar( ) = abap_false.
        APPEND VALUE #( %msg = msg( zcx_pc_msg=>sem_autorizacao ) ) TO reported-cliente.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-cliente.
        CONTINUE.
      ENDIF.

      " 1) Leitura do arquivo (XLSX ou CSV)
      zcl_pc_planilha=>ler( EXPORTING iv_conteudo  = ls_key-%param-_StreamProperties-StreamProperty
                                      it_colunas   = lt_colunas
                            IMPORTING et_registros = DATA(lt_registros)
                                      et_erros     = lt_erros ).
      IF lt_erros IS NOT INITIAL.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 2) Validação linha a linha (todas as linhas são avaliadas antes de gravar)
      SELECT cpf FROM zta_pc_cliente INTO TABLE @DATA(lt_cpf_db).
      DATA(lv_hoje) = cl_abap_context_info=>get_system_date( ).

      LOOP AT lt_registros INTO DATA(ls_reg).
        DATA(lv_pref)   = |Linha { ls_reg-linha }: |.
        DATA(lv_antes)  = lines( lt_erros ).
        DATA(ls_cli)    = VALUE ty_cliente( linha = ls_reg-linha ).

        DATA(lv_cpf_txt) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-cpf ).
        ls_cli-cpf = zcl_pc_importacao=>normalizar_cpf( lv_cpf_txt ).
        IF zcl_pc_util=>validar_cpf( ls_cli-cpf ) = abap_false.
          APPEND |{ lv_pref }CPF inválido ({ lv_cpf_txt }).| TO lt_erros.
        ELSEIF line_exists( lt_cpf_db[ cpf = ls_cli-cpf ] ).
          APPEND |{ lv_pref }já existe cliente com o CPF { zcl_pc_util=>formatar_cpf( ls_cli-cpf ) }.| TO lt_erros.
        ELSEIF line_exists( lt_cpf_arq[ table_line = ls_cli-cpf ] ).
          APPEND |{ lv_pref }CPF { zcl_pc_util=>formatar_cpf( ls_cli-cpf ) } repetido na planilha.| TO lt_erros.
        ELSE.
          INSERT ls_cli-cpf INTO TABLE lt_cpf_arq.
        ENDIF.

        DATA(lv_nome) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-nome ).
        IF lv_nome IS INITIAL.
          APPEND |{ lv_pref }Nome é obrigatório.| TO lt_erros.
        ELSEIF strlen( lv_nome ) > 255.
          APPEND |{ lv_pref }Nome excede 255 caracteres.| TO lt_erros.
        ELSE.
          ls_cli-nome = lv_nome.
        ENDIF.

        DATA(lv_email) = to_lower( zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-email ) ).
        IF lv_email IS INITIAL OR zcl_pc_util=>validar_email( lv_email ) = abap_false.
          APPEND |{ lv_pref }E-mail inválido ({ lv_email }).| TO lt_erros.
        ELSEIF strlen( lv_email ) > 100.
          APPEND |{ lv_pref }E-mail excede 100 caracteres.| TO lt_erros.
        ELSE.
          ls_cli-email = lv_email.
        ENDIF.

        DATA(lv_tel) = zcl_pc_util=>somente_digitos( zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-telefone ) ).
        IF strlen( lv_tel ) < 10 OR strlen( lv_tel ) > 11.
          APPEND |{ lv_pref }Telefone deve ter 10 ou 11 dígitos (DDD + número).| TO lt_erros.
        ELSE.
          ls_cli-telefone = lv_tel.
        ENDIF.

        DATA(lv_genero_txt) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-genero ).
        IF lv_genero_txt IS NOT INITIAL.
          DATA(lv_genero) = zcl_pc_importacao=>converter_codelist( iv_lista = zif_pc_constants=>c_codelist-genero
                                                                   iv_texto = lv_genero_txt ).
          IF lv_genero IS INITIAL.
            APPEND |{ lv_pref }Gênero inválido ({ lv_genero_txt }). Use: { zcl_pc_importacao=>opcoes_codelist( zif_pc_constants=>c_codelist-genero ) }.| TO lt_erros.
          ELSE.
            ls_cli-genero = lv_genero.
          ENDIF.
        ENDIF.

        DATA(lv_nasc_txt) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-nascimento ).
        DATA(lv_nasc)     = zcl_pc_planilha=>para_data( lv_nasc_txt ).
        IF lv_nasc IS INITIAL.
          APPEND |{ lv_pref }Data de nascimento inválida ({ lv_nasc_txt }). Use AAAA-MM-DD ou DD/MM/AAAA.| TO lt_erros.
        ELSEIF lv_nasc > lv_hoje.
          APPEND |{ lv_pref }Data de nascimento não pode ser futura.| TO lt_erros.
        ELSE.
          ls_cli-nascimento = lv_nasc.
        ENDIF.

        DATA(lv_cep) = zcl_pc_importacao=>normalizar_cep( zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-cep ) ).
        IF strlen( lv_cep ) <> 8.
          APPEND |{ lv_pref }CEP deve ter 8 dígitos.| TO lt_erros.
        ELSE.
          ls_cli-cep = lv_cep.
        ENDIF.

        DATA(lv_numero) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-numero ).
        IF lv_numero IS INITIAL.
          APPEND |{ lv_pref }Número do endereço é obrigatório.| TO lt_erros.
        ELSEIF strlen( lv_numero ) > 20.
          APPEND |{ lv_pref }Número do endereço excede 20 caracteres.| TO lt_erros.
        ELSE.
          ls_cli-numero = lv_numero.
        ENDIF.

        DATA(lv_compl) = zcl_pc_planilha=>valor( is_registro = ls_reg iv_campo = c_col-complemento ).
        IF strlen( lv_compl ) > 100.
          APPEND |{ lv_pref }Complemento excede 100 caracteres.| TO lt_erros.
        ELSE.
          ls_cli-complemento = lv_compl.
        ENDIF.

        IF lines( lt_erros ) = lv_antes.
          APPEND ls_cli TO lt_cli.
        ENDIF.
      ENDLOOP.

      IF lt_erros IS NOT INITIAL.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 3) Criação (instâncias ativas): as determinations normalizam os dados,
      "    consultam o CEP (ViaCEP) e definem o endereço principal; as
      "    validations rodam no save. Um erro em qualquer linha cancela tudo.
      DATA lt_cria_cli TYPE TABLE FOR CREATE zr_pc_cliente\\Cliente.
      DATA lt_cria_end TYPE TABLE FOR CREATE zr_pc_cliente\\Cliente\_Endereco.
      CLEAR: lt_cria_cli, lt_cria_end.

      LOOP AT lt_cli INTO ls_cli.
        APPEND VALUE #( %cid           = |CLI{ ls_cli-linha }|
                        Cpf            = ls_cli-cpf
                        Nome           = ls_cli-nome
                        Email          = ls_cli-email
                        Telefone       = ls_cli-telefone
                        Genero         = ls_cli-genero
                        DataNascimento = ls_cli-nascimento ) TO lt_cria_cli.
        APPEND VALUE #( %cid_ref = |CLI{ ls_cli-linha }|
                        %target  = VALUE #( ( %cid        = |END{ ls_cli-linha }|
                                              Cep         = ls_cli-cep
                                              Numero      = ls_cli-numero
                                              Complemento = ls_cli-complemento ) ) ) TO lt_cria_end.
      ENDLOOP.

      MODIFY ENTITIES OF zr_pc_cliente IN LOCAL MODE
        ENTITY Cliente
          CREATE FIELDS ( Cpf Nome Email Telefone Genero DataNascimento )
          WITH lt_cria_cli
          CREATE BY \_Endereco FIELDS ( Cep Numero Complemento )
          WITH lt_cria_end
        MAPPED   DATA(ls_mapped)
        FAILED   DATA(ls_failed)
        REPORTED DATA(ls_reported).

      IF ls_failed-cliente IS NOT INITIAL OR ls_failed-endereco IS NOT INITIAL.
        APPEND `Não foi possível criar os clientes.` TO lt_erros.
        LOOP AT ls_reported-cliente INTO DATA(ls_rep_cli) WHERE %msg IS BOUND.
          APPEND |{ linha_do_cid( ls_rep_cli-%cid ) }{ ls_rep_cli-%msg->if_message~get_text( ) }| TO lt_erros.
        ENDLOOP.
        LOOP AT ls_reported-endereco INTO DATA(ls_rep_end) WHERE %msg IS BOUND.
          APPEND |{ linha_do_cid( ls_rep_end-%cid ) }{ ls_rep_end-%msg->if_message~get_text( ) }| TO lt_erros.
        ENDLOOP.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      " 4) CEP: o ViaCEP é consultado nas determinations; CEP não validado
      "    (inexistente ou serviço fora do ar) cancela a importação agora, em
      "    vez de falhar no save sem dizer qual linha.
      READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
        ENTITY Endereco
          FIELDS ( Cep CepStatus )
          WITH CORRESPONDING #( ls_mapped-endereco )
        RESULT DATA(lt_enderecos).

      LOOP AT lt_enderecos INTO DATA(ls_end)
           WHERE CepStatus <> zif_pc_constants=>c_status_cep-validado.
        READ TABLE ls_mapped-endereco INTO DATA(ls_map_end) WITH KEY EnderecoUUID = ls_end-EnderecoUUID.
        DATA(lv_motivo) = COND string(
          WHEN ls_end-CepStatus = zif_pc_constants=>c_status_cep-indisponivel
          THEN `consulta de CEP indisponível no momento, tente novamente`
          ELSE `CEP inexistente` ).
        APPEND |{ linha_do_cid( ls_map_end-%cid ) }CEP { ls_end-Cep }: { lv_motivo }.| TO lt_erros.
      ENDLOOP.

      IF lt_erros IS NOT INITIAL.
        falhar_importacao( EXPORTING it_erros = lt_erros iv_cid = ls_key-%cid
                           CHANGING  cs_failed = failed cs_reported = reported ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %msg = zcx_pc_msg=>texto(
                               iv_texto    = |Importação concluída: { lines( lt_cli ) } cliente(s) criado(s). Atualize a lista.|
                               iv_severity = if_abap_behv_message=>severity-success ) )
             TO reported-cliente.
    ENDLOOP.
  ENDMETHOD.


  METHOD falhar_importacao.
    APPEND VALUE #( %msg = zcx_pc_msg=>texto(
                             |Importação cancelada: nenhum cliente foi gravado ({ lines( it_erros ) } erro(s)).| ) )
           TO cs_reported-cliente.

    LOOP AT zcl_pc_importacao=>resumir_erros( it_erros ) INTO DATA(lv_erro).
      APPEND VALUE #( %msg = zcx_pc_msg=>texto( lv_erro ) ) TO cs_reported-cliente.
    ENDLOOP.

    APPEND VALUE #( %cid = iv_cid ) TO cs_failed-cliente.
  ENDMETHOD.


  METHOD linha_do_cid.
    DATA(lv_numero) = match( val = iv_cid pcre = `\d+` ).
    rv_texto = COND #( WHEN lv_numero IS NOT INITIAL THEN |Linha { lv_numero }: | ).
  ENDMETHOD.


  METHOD msg.
    ro_msg = NEW zcx_pc_msg( textid = textid
                             attr1  = attr1 ).
  ENDMETHOD.

ENDCLASS.


"! Handler da entidade Endereço (child)
CLASS lhc_endereco DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_area,
        numero    TYPE string VALUE `VALIDAR_NUMERO`,
        cep       TYPE string VALUE `VALIDAR_CEP`,
        cep_unico TYPE string VALUE `VALIDAR_CEP_UNICO`,
      END OF c_area.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Endereco RESULT result.

    METHODS DefinirEnderecoPrincipal FOR MODIFY
      IMPORTING keys FOR ACTION Endereco~DefinirEnderecoPrincipal RESULT result.

    METHODS PreencherEnderecoViaCep FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Endereco~PreencherEnderecoViaCep.

    METHODS DefinirPrincipalInicial FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Endereco~DefinirPrincipalInicial.

    METHODS ValidarNumero FOR VALIDATE ON SAVE
      IMPORTING keys FOR Endereco~ValidarNumero.

    METHODS ValidarCep FOR VALIDATE ON SAVE
      IMPORTING keys FOR Endereco~ValidarCep.

    METHODS ValidarCepUnico FOR VALIDATE ON SAVE
      IMPORTING keys FOR Endereco~ValidarCepUnico.
ENDCLASS.


CLASS lhc_endereco IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        FIELDS ( CepGeral EnderecoPrincipal )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_enderecos).

    result = VALUE #( FOR e IN lt_enderecos
                      ( %tky              = e-%tky
                        %field-Logradouro = COND #( WHEN e-CepGeral = abap_true
                                                    THEN if_abap_behv=>fc-f-mandatory
                                                    ELSE if_abap_behv=>fc-f-read_only )
                        %field-Bairro     = COND #( WHEN e-CepGeral = abap_true
                                                    THEN if_abap_behv=>fc-f-mandatory
                                                    ELSE if_abap_behv=>fc-f-read_only )
                        %action-DefinirEnderecoPrincipal = COND #( WHEN e-EnderecoPrincipal = abap_true
                                                                   THEN if_abap_behv=>fc-o-disabled
                                                                   ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.


  METHOD DefinirEnderecoPrincipal.
    DATA lt_pais   TYPE TABLE FOR READ IMPORT zr_pc_cliente\\Cliente\_Endereco.
    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_cliente\\Endereco.

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        FIELDS ( ClienteUUID EnderecoPrincipal )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_alvos).

    " Um cliente por linha (a última seleção do mesmo cliente prevalece)
    LOOP AT lt_alvos INTO DATA(ls_alvo).
      IF NOT line_exists( lt_pais[ %is_draft = ls_alvo-%is_draft ClienteUUID = ls_alvo-ClienteUUID ] ).
        APPEND VALUE #( %is_draft = ls_alvo-%is_draft ClienteUUID = ls_alvo-ClienteUUID ) TO lt_pais.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente BY \_Endereco
        FIELDS ( ClienteUUID EnderecoPrincipal )
        WITH lt_pais
      RESULT DATA(lt_irmaos).

    LOOP AT lt_pais INTO DATA(ls_pai).
      " Endereço escolhido para este cliente = último da lista de alvos
      DATA(lv_escolhido) = VALUE sysuuid_x16( ).
      LOOP AT lt_alvos INTO ls_alvo WHERE ClienteUUID = ls_pai-ClienteUUID AND %is_draft = ls_pai-%is_draft.
        lv_escolhido = ls_alvo-EnderecoUUID.
      ENDLOOP.

      LOOP AT lt_irmaos INTO DATA(ls_irmao)
           WHERE ClienteUUID = ls_pai-ClienteUUID AND %is_draft = ls_pai-%is_draft.
        DATA(lv_principal) = xsdbool( ls_irmao-EnderecoUUID = lv_escolhido ).
        IF lv_principal <> ls_irmao-EnderecoPrincipal.
          APPEND VALUE #( %tky              = ls_irmao-%tky
                          EnderecoPrincipal = lv_principal
                          %control-EnderecoPrincipal = if_abap_behv=>mk-on ) TO lt_update.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zr_pc_cliente IN LOCAL MODE
        ENTITY Endereco UPDATE FROM lt_update
        FAILED DATA(ls_failed)
        REPORTED DATA(ls_reported).

      failed   = CORRESPONDING #( DEEP ls_failed ).
      reported = CORRESPONDING #( DEEP ls_reported ).
    ENDIF.

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).

    result = VALUE #( FOR r IN lt_resultado ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.


  METHOD PreencherEnderecoViaCep.
    " Única fase em que o ViaCEP é chamado (fase de interação). A fase de save
    " não faz I/O remoto: a validation apenas avalia CepStatus/Cidade/Uf.
    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_cliente\\Endereco.

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        FIELDS ( ClienteUUID Cep )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_enderecos).

    LOOP AT lt_enderecos INTO DATA(ls_end).
      DATA(lv_cep) = zcl_pc_util=>somente_digitos( ls_end-Cep ).
      DATA(ls_dados) = VALUE zcl_pc_viacep=>ty_endereco( ).
      DATA(lv_status) = CONV zr_pc_endereco-CepStatus( space ).
      DATA(lv_geral)  = abap_false.

      IF strlen( lv_cep ) <> 8.
        lv_status = COND #( WHEN lv_cep IS INITIAL
                            THEN space
                            ELSE zif_pc_constants=>c_status_cep-invalido ).
      ELSE.
        " 1) CEP já validado em outro endereço do cadastro (mesma regra da value
        "    help ZC_PC_CEP_VH): reaproveita os dados, sem chamada remota.
        "    CEP geral fica de fora: logradouro/bairro variam por endereço.
        SELECT SINGLE Logradouro, Bairro, Cidade, Uf, Estado
          FROM zr_pc_endereco
          WHERE Cep       = @lv_cep
            AND CepStatus = @zif_pc_constants=>c_status_cep-validado
            AND CepGeral  = @abap_false
          INTO @DATA(ls_cadastrado).

        IF sy-subrc = 0.
          lv_status = zif_pc_constants=>c_status_cep-validado.
          ls_dados  = VALUE #( logradouro = ls_cadastrado-Logradouro
                               bairro     = ls_cadastrado-Bairro
                               localidade = ls_cadastrado-Cidade
                               uf         = ls_cadastrado-Uf
                               estado     = ls_cadastrado-Estado ).
        ELSE.
          " 2) CEP ainda não cadastrado: consulta o ViaCEP
          DATA(ls_viacep) = zcl_pc_viacep=>consultar( lv_cep ).
          IF ls_viacep-indisponivel = abap_true.
            lv_status = zif_pc_constants=>c_status_cep-indisponivel.
            APPEND VALUE #( %tky = ls_end-%tky
                            %msg = NEW zcx_pc_msg( textid   = zcx_pc_msg=>cep_indisponivel
                                                   severity = if_abap_behv_message=>severity-warning )
                            %path = VALUE #( cliente-%is_draft   = ls_end-%is_draft
                                             cliente-ClienteUUID = ls_end-ClienteUUID ) ) TO reported-endereco.
          ELSEIF ls_viacep-valido = abap_true.
            lv_status = zif_pc_constants=>c_status_cep-validado.
            ls_dados  = ls_viacep-endereco.
            lv_geral  = ls_viacep-cep_geral.
          ELSE.
            lv_status = zif_pc_constants=>c_status_cep-invalido.
          ENDIF.
        ENDIF.
      ENDIF.

      APPEND VALUE #( %tky       = ls_end-%tky
                      Logradouro = ls_dados-logradouro
                      Bairro     = ls_dados-bairro
                      Cidade     = ls_dados-localidade
                      Uf         = ls_dados-uf
                      Estado     = COND #( WHEN ls_dados-estado IS NOT INITIAL
                                           THEN ls_dados-estado
                                           ELSE ls_dados-uf )
                      CepGeral   = lv_geral
                      CepStatus  = lv_status
                      %control = VALUE #( Logradouro = if_abap_behv=>mk-on Bairro    = if_abap_behv=>mk-on
                                          Cidade     = if_abap_behv=>mk-on Uf        = if_abap_behv=>mk-on
                                          Estado     = if_abap_behv=>mk-on CepGeral  = if_abap_behv=>mk-on
                                          CepStatus  = if_abap_behv=>mk-on ) )
             TO lt_update ASSIGNING FIELD-SYMBOL(<ls_update_cep>).

      " Só regrava o Cep quando a normalização mudou o valor (ex.: com máscara).
      " Reescrever o mesmo valor reaciona esta determination (trigger "field
      " Cep") indefinidamente: RAISE_SHORTDUMP / LCX_ABAP_BEHV_DETVAL_ERROR
      " "stack of on-modify determinations being too deep".
      IF lv_cep <> ls_end-Cep.
        <ls_update_cep>-Cep          = lv_cep.
        <ls_update_cep>-%control-Cep = if_abap_behv=>mk-on.
      ENDIF.
    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco UPDATE FROM lt_update
      REPORTED DATA(ls_reported).

    LOOP AT ls_reported-endereco INTO DATA(ls_rep) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep ) TO reported-endereco.
    ENDLOOP.
  ENDMETHOD.


  METHOD DefinirPrincipalInicial.
    DATA lt_pais   TYPE TABLE FOR READ IMPORT zr_pc_cliente\\Cliente\_Endereco.
    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_cliente\\Endereco.

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        FIELDS ( ClienteUUID EnderecoPrincipal )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_novos).

    LOOP AT lt_novos INTO DATA(ls_novo).
      IF NOT line_exists( lt_pais[ %is_draft = ls_novo-%is_draft ClienteUUID = ls_novo-ClienteUUID ] ).
        APPEND VALUE #( %is_draft = ls_novo-%is_draft ClienteUUID = ls_novo-ClienteUUID ) TO lt_pais.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente BY \_Endereco
        FIELDS ( ClienteUUID EnderecoPrincipal )
        WITH lt_pais
      RESULT DATA(lt_todos).

    " Se o cliente ainda não tem endereço principal, o primeiro novo endereço vira principal
    LOOP AT lt_pais INTO DATA(ls_pai).
      IF line_exists( lt_todos[ ClienteUUID = ls_pai-ClienteUUID %is_draft = ls_pai-%is_draft EnderecoPrincipal = abap_true ] ).
        CONTINUE.
      ENDIF.
      READ TABLE lt_novos INTO ls_novo WITH KEY ClienteUUID = ls_pai-ClienteUUID %is_draft = ls_pai-%is_draft.
      IF sy-subrc = 0.
        APPEND VALUE #( %tky = ls_novo-%tky
                        EnderecoPrincipal = abap_true
                        %control-EnderecoPrincipal = if_abap_behv=>mk-on ) TO lt_update.
      ENDIF.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco UPDATE FROM lt_update
      REPORTED DATA(ls_reported_prin).

    LOOP AT ls_reported_prin-endereco INTO DATA(ls_rep_prin) WHERE %msg IS BOUND.
      APPEND CORRESPONDING #( ls_rep_prin ) TO reported-endereco.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarNumero.
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        FIELDS ( ClienteUUID Numero )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_enderecos).

    LOOP AT lt_enderecos INTO DATA(ls_end).
      APPEND VALUE #( %tky        = ls_end-%tky
                      %state_area = c_area-numero ) TO reported-endereco.

      IF condense( ls_end-Numero ) = ``.
        APPEND VALUE #( %tky = ls_end-%tky ) TO failed-endereco.
        APPEND VALUE #( %tky        = ls_end-%tky
                        %state_area = c_area-numero
                        %msg        = NEW zcx_pc_msg( textid = zcx_pc_msg=>endereco_numero_obrigatorio )
                        %element-Numero = if_abap_behv=>mk-on
                        %path       = VALUE #( cliente-%is_draft   = ls_end-%is_draft
                                               cliente-ClienteUUID = ls_end-ClienteUUID ) ) TO reported-endereco.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarCep.
    " Sem chamada remota: a fase de save avalia apenas o que a determination
    " PreencherEnderecoViaCep já gravou (CepStatus, Cidade, Uf, CepGeral).
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        FIELDS ( ClienteUUID Cep Logradouro Bairro Cidade Uf CepGeral CepStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_enderecos).

    DATA lo_msg TYPE REF TO zcx_pc_msg.

    LOOP AT lt_enderecos INTO DATA(ls_end).
      APPEND VALUE #( %tky        = ls_end-%tky
                      %state_area = c_area-cep ) TO reported-endereco.

      CLEAR lo_msg.
      DATA(lv_cep) = zcl_pc_util=>somente_digitos( ls_end-Cep ).

      IF strlen( lv_cep ) <> 8.
        lo_msg = NEW #( textid = zcx_pc_msg=>cep_invalido ).
      ELSEIF ls_end-CepStatus = zif_pc_constants=>c_status_cep-indisponivel.
        lo_msg = NEW #( textid = zcx_pc_msg=>cep_indisponivel ).
      ELSEIF ls_end-CepStatus <> zif_pc_constants=>c_status_cep-validado
             OR ls_end-Cidade IS INITIAL
             OR ls_end-Uf IS INITIAL.
        lo_msg = NEW #( textid = zcx_pc_msg=>cep_invalido ).
      ELSEIF ls_end-CepGeral = abap_true AND ls_end-Logradouro IS INITIAL.
        lo_msg = NEW #( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Logradouro' ).
      ELSEIF ls_end-CepGeral = abap_true AND ls_end-Bairro IS INITIAL.
        lo_msg = NEW #( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Bairro' ).
      ENDIF.

      IF lo_msg IS BOUND.
        APPEND VALUE #( %tky = ls_end-%tky ) TO failed-endereco.
        APPEND VALUE #( %tky         = ls_end-%tky
                        %state_area  = c_area-cep
                        %msg         = lo_msg
                        %element-Cep = if_abap_behv=>mk-on
                        %path        = VALUE #( cliente-%is_draft   = ls_end-%is_draft
                                                cliente-ClienteUUID = ls_end-ClienteUUID ) ) TO reported-endereco.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ValidarCepUnico.
    " Cada cliente só pode ter um endereço cadastrado por CEP (a mesma rua
    " pode, claro, ter clientes diferentes - a unicidade é por ClienteUUID).
    " Usa READ ENTITIES (não SQL puro na tabela ativa) para também flagrar
    " duplicidade entre endereços ainda em draft, na mesma edição, antes de
    " qualquer commit (a tabela ativa ainda não teria nenhum dos dois).
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        FIELDS ( ClienteUUID EnderecoUUID Cep )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_enderecos).

    CHECK lt_enderecos IS NOT INITIAL.

    DATA lt_pais TYPE TABLE FOR READ IMPORT zr_pc_cliente\\Cliente\_Endereco.
    LOOP AT lt_enderecos INTO DATA(ls_end0).
      IF NOT line_exists( lt_pais[ %is_draft = ls_end0-%is_draft ClienteUUID = ls_end0-ClienteUUID ] ).
        APPEND VALUE #( %is_draft = ls_end0-%is_draft ClienteUUID = ls_end0-ClienteUUID ) TO lt_pais.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente BY \_Endereco
        FIELDS ( ClienteUUID EnderecoUUID Cep )
        WITH lt_pais
      RESULT DATA(lt_irmaos).

    LOOP AT lt_enderecos INTO DATA(ls_end).
      APPEND VALUE #( %tky        = ls_end-%tky
                      %state_area = c_area-cep_unico ) TO reported-endereco.

      DATA(lv_cep) = zcl_pc_util=>somente_digitos( ls_end-Cep ).
      CHECK strlen( lv_cep ) = 8.

      DATA(lv_duplicado) = abap_false.
      LOOP AT lt_irmaos INTO DATA(ls_irmao)
           WHERE %is_draft   = ls_end-%is_draft
             AND ClienteUUID = ls_end-ClienteUUID
             AND Cep         = ls_end-Cep
             AND EnderecoUUID <> ls_end-EnderecoUUID.
        lv_duplicado = abap_true.
        EXIT.
      ENDLOOP.

      IF lv_duplicado = abap_true.
        APPEND VALUE #( %tky = ls_end-%tky ) TO failed-endereco.
        APPEND VALUE #( %tky        = ls_end-%tky
                        %state_area = c_area-cep_unico
                        %msg        = NEW zcx_pc_msg( textid = zcx_pc_msg=>cep_duplicado_cliente )
                        %element-Cep = if_abap_behv=>mk-on
                        %path       = VALUE #( cliente-%is_draft   = ls_end-%is_draft
                                               cliente-ClienteUUID = ls_end-ClienteUUID ) ) TO reported-endereco.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
