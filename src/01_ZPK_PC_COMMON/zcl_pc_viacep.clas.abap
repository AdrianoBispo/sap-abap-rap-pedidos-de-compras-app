"! <p class="shorttext synchronized">Pedidos de Compras - Consulta de CEP (ViaCEP)</p>
"! Trial: usa cl_http_destination_provider=>create_by_url (URL pública).
"! Produção: substituir por create_by_comm_arrangement (Communication
"! Scenario + Outbound Service HTTP + Communication Arrangement).
CLASS zcl_pc_viacep DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_endereco,
        cep         TYPE string,
        logradouro  TYPE string,
        complemento TYPE string,
        bairro      TYPE string,
        localidade  TYPE string,
        uf          TYPE string,
        estado      TYPE string,
        erro        TYPE string,
      END OF ty_endereco.

    TYPES:
      BEGIN OF ty_resultado,
        "! CEP existe e dados foram retornados
        valido      TYPE abap_boolean,
        "! Serviço indisponível (timeout, erro HTTP 5xx, rede)
        indisponivel TYPE abap_boolean,
        "! CEP geral de município: ViaCEP não retorna logradouro/bairro
        cep_geral   TYPE abap_boolean,
        endereco    TYPE ty_endereco,
      END OF ty_resultado.

    CONSTANTS c_url_base TYPE string VALUE `https://viacep.com.br/ws/`.

    "! Consulta o CEP (8 dígitos). Resultados ficam em cache por sessão
    "! para evitar chamadas repetidas entre determination e validation.
    CLASS-METHODS consultar
      IMPORTING iv_cep              TYPE csequence
      RETURNING VALUE(rs_resultado) TYPE ty_resultado.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_cache,
        cep       TYPE string,
        resultado TYPE ty_resultado,
      END OF ty_cache.

    CLASS-DATA gt_cache TYPE HASHED TABLE OF ty_cache WITH UNIQUE KEY cep.

    CLASS-METHODS chamar_servico
      IMPORTING iv_cep              TYPE string
      RETURNING VALUE(rs_resultado) TYPE ty_resultado.
ENDCLASS.



CLASS zcl_pc_viacep IMPLEMENTATION.

  METHOD consultar.
    DATA(lv_cep) = zcl_pc_util=>somente_digitos( iv_cep ).

    IF strlen( lv_cep ) <> 8.
      rs_resultado-valido = abap_false.
      RETURN.
    ENDIF.

    " Cache apenas para respostas definitivas (não armazena indisponibilidade)
    READ TABLE gt_cache WITH TABLE KEY cep = lv_cep INTO DATA(ls_cache).
    IF sy-subrc = 0.
      rs_resultado = ls_cache-resultado.
      RETURN.
    ENDIF.

    rs_resultado = chamar_servico( lv_cep ).

    IF rs_resultado-indisponivel = abap_false.
      INSERT VALUE #( cep = lv_cep resultado = rs_resultado ) INTO TABLE gt_cache.
    ENDIF.
  ENDMETHOD.


  METHOD chamar_servico.
    DATA lv_status TYPE i.
    DATA lv_json   TYPE string.

    TRY.
        DATA(lo_destino) = cl_http_destination_provider=>create_by_url(
                             i_url = |{ c_url_base }{ iv_cep }/json/| ).

        DATA(lo_cliente) = cl_web_http_client_manager=>create_by_http_destination( lo_destino ).
        lo_cliente->get_http_request( )->set_header_field( i_name  = `Accept`
                                                            i_value = `application/json` ).

        DATA(lo_resposta) = lo_cliente->execute( if_web_http_client=>get ).
        lv_status = lo_resposta->get_status( )-code.
        lv_json   = lo_resposta->get_text( ).
        lo_cliente->close( ).

      CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error.
        rs_resultado-indisponivel = abap_true.
        RETURN.
    ENDTRY.

    CASE lv_status.
      WHEN 200.
        " segue para o parse
      WHEN 400 OR 404.
        " Formato inválido segundo o ViaCEP
        rs_resultado-valido = abap_false.
        RETURN.
      WHEN OTHERS.
        rs_resultado-indisponivel = abap_true.
        RETURN.
    ENDCASE.

    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json = lv_json
                                   CHANGING  data = rs_resultado-endereco ).
      CATCH cx_root.
        rs_resultado-indisponivel = abap_true.
        RETURN.
    ENDTRY.

    " CEP inexistente: {"erro": true} ou {"erro": "true"}
    IF rs_resultado-endereco-erro IS NOT INITIAL
       OR rs_resultado-endereco-localidade IS INITIAL.
      rs_resultado-valido = abap_false.
      RETURN.
    ENDIF.

    rs_resultado-valido    = abap_true.
    rs_resultado-cep_geral = xsdbool( rs_resultado-endereco-logradouro IS INITIAL ).
  ENDMETHOD.

ENDCLASS.
