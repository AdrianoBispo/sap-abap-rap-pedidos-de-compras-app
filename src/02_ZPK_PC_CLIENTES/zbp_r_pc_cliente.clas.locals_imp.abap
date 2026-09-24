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

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Cliente RESULT result.

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
    DATA(lv_auth) = COND #( WHEN zcl_pc_auth=>is_admin( ) = abap_true
                            THEN if_abap_behv=>auth-allowed
                            ELSE if_abap_behv=>auth-unauthorized ).

    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = lv_auth.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = lv_auth.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = lv_auth.
    ENDIF.
    IF requested_authorizations-%action-Edit = if_abap_behv=>mk-on.
      result-%action-Edit = lv_auth.
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

    " Novo cliente nasce ativo
    DELETE lt_clientes WHERE ClienteAtivo = abap_true.
    CHECK lt_clientes IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Cliente
        UPDATE FIELDS ( ClienteAtivo )
        WITH VALUE #( FOR c IN lt_clientes
                      ( %tky         = c-%tky
                        ClienteAtivo = abap_true ) ).
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
      ENTITY Cliente UPDATE FROM lt_update.
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
        numero TYPE string VALUE `VALIDAR_NUMERO`,
        cep    TYPE string VALUE `VALIDAR_CEP`,
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
    DATA lt_update TYPE TABLE FOR UPDATE zr_pc_cliente\\Endereco.

    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        FIELDS ( Cep )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_enderecos).

    LOOP AT lt_enderecos INTO DATA(ls_end).
      DATA(lv_cep) = zcl_pc_util=>somente_digitos( ls_end-Cep ).

      " Sem CEP válido: limpa dados derivados (ValidarCep reportará o erro)
      IF strlen( lv_cep ) <> 8.
        APPEND VALUE #( %tky = ls_end-%tky
                        Logradouro = `` Bairro = `` Cidade = `` Uf = `` Estado = `` CepGeral = abap_false
                        %control = VALUE #( Logradouro = if_abap_behv=>mk-on Bairro = if_abap_behv=>mk-on
                                            Cidade     = if_abap_behv=>mk-on Uf     = if_abap_behv=>mk-on
                                            Estado     = if_abap_behv=>mk-on CepGeral = if_abap_behv=>mk-on ) )
               TO lt_update.
        CONTINUE.
      ENDIF.

      DATA(ls_viacep) = zcl_pc_viacep=>consultar( lv_cep ).

      IF ls_viacep-valido = abap_true.
        APPEND VALUE #( %tky       = ls_end-%tky
                        Cep        = lv_cep
                        Logradouro = ls_viacep-endereco-logradouro
                        Bairro     = ls_viacep-endereco-bairro
                        Cidade     = ls_viacep-endereco-localidade
                        Uf         = ls_viacep-endereco-uf
                        Estado     = COND #( WHEN ls_viacep-endereco-estado IS NOT INITIAL
                                             THEN ls_viacep-endereco-estado
                                             ELSE ls_viacep-endereco-uf )
                        CepGeral   = ls_viacep-cep_geral
                        %control = VALUE #( Cep        = if_abap_behv=>mk-on
                                            Logradouro = if_abap_behv=>mk-on Bairro = if_abap_behv=>mk-on
                                            Cidade     = if_abap_behv=>mk-on Uf     = if_abap_behv=>mk-on
                                            Estado     = if_abap_behv=>mk-on CepGeral = if_abap_behv=>mk-on ) )
               TO lt_update.
      ELSE.
        " CEP inexistente ou serviço indisponível: não preenche nada
        APPEND VALUE #( %tky = ls_end-%tky
                        Cep  = lv_cep
                        Logradouro = `` Bairro = `` Cidade = `` Uf = `` Estado = `` CepGeral = abap_false
                        %control = VALUE #( Cep        = if_abap_behv=>mk-on
                                            Logradouro = if_abap_behv=>mk-on Bairro = if_abap_behv=>mk-on
                                            Cidade     = if_abap_behv=>mk-on Uf     = if_abap_behv=>mk-on
                                            Estado     = if_abap_behv=>mk-on CepGeral = if_abap_behv=>mk-on ) )
               TO lt_update.
      ENDIF.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco UPDATE FROM lt_update.
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
      ENTITY Endereco UPDATE FROM lt_update.
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
    READ ENTITIES OF zr_pc_cliente IN LOCAL MODE
      ENTITY Endereco
        FIELDS ( ClienteUUID Cep Logradouro Bairro CepGeral )
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
      ELSE.
        " Validação definitiva no backend: consulta o ViaCEP novamente (cache por sessão)
        DATA(ls_viacep) = zcl_pc_viacep=>consultar( lv_cep ).
        IF ls_viacep-indisponivel = abap_true.
          lo_msg = NEW #( textid = zcx_pc_msg=>cep_indisponivel ).
        ELSEIF ls_viacep-valido = abap_false.
          lo_msg = NEW #( textid = zcx_pc_msg=>cep_invalido ).
        ELSEIF ls_viacep-cep_geral = abap_true AND ls_end-Logradouro IS INITIAL.
          lo_msg = NEW #( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Logradouro' ).
        ELSEIF ls_viacep-cep_geral = abap_true AND ls_end-Bairro IS INITIAL.
          lo_msg = NEW #( textid = zcx_pc_msg=>campo_obrigatorio attr1 = 'Bairro' ).
        ENDIF.
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

ENDCLASS.
