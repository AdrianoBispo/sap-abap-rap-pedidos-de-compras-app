"! <p class="shorttext synchronized">Pedidos de Compras - Consulta de CEP (ViaCEP)</p>
"! Versão On-Premise (SAP S/4HANA 2025). Substitui a classe de mesmo nome da
"! pasta ZCL_PC_VIACEP, que usa cl_http_destination_provider=>create_by_url
"! (SAP BTP, ABAP environment). Crie no sistema apenas uma das duas versões.
"!
"! A classe usa CL_HTTP_CLIENT, API clássica: crie-a no pacote ZAVBS_PC_COMMON
"! com versão de linguagem "Standard ABAP", como os demais objetos do projeto
"! no On-Premise. Só se os pacotes forem mantidos em "ABAP for Cloud
"! Development" é preciso isolá-la num subpacote Standard ABAP e liberá-la com
"! o contrato C1 (Use in Cloud Development).
"!
"! A URL não fica no código: host, porta, SSL e proxy estão na destination
"! HTTP Z_VIACEP (SM59, tipo G) e a confiança TLS no STRUST (PSE SSL Client
"! Anonymous). Ver abap/README.md, seção 5.
"!
"! A interface pública (ty_endereco, ty_resultado, consultar) é um
"! superconjunto da versão BTP: o behavior pool ZBP_R_PC_CLIENTE não muda.
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
        valido        TYPE abap_boolean,
        "! Serviço indisponível (destination, timeout, HTTP 408/429/5xx, rede)
        indisponivel  TYPE abap_boolean,
        "! CEP geral de município: ViaCEP não retorna logradouro/bairro
        cep_geral     TYPE abap_boolean,
        "! Status HTTP da resposta (0 quando não houve resposta)
        status_http   TYPE i,
        "! Detalhe técnico para log/diagnóstico (não exibir ao usuário final)
        mensagem_erro TYPE string,
        endereco      TYPE ty_endereco,
      END OF ty_resultado.

    "! Destination HTTP (SM59, tipo G) com host viacep.com.br, porta 443 e SSL
    CONSTANTS c_destination TYPE c LENGTH 32 VALUE 'Z_VIACEP'.

    "! Consulta o CEP (8 dígitos). Resultados definitivos ficam em cache por
    "! sessão (limitado a c_max_cache entradas) para evitar chamadas repetidas.
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

    CONSTANTS c_max_cache TYPE i VALUE 100.
    CONSTANTS c_timeout   TYPE i VALUE 30.

    CLASS-DATA gt_cache TYPE STANDARD TABLE OF ty_cache WITH EMPTY KEY.

    CLASS-METHODS chamar_servico
      IMPORTING iv_cep              TYPE string
      RETURNING VALUE(rs_resultado) TYPE ty_resultado.

    "! Extrai um campo de um JSON plano ("campo": "valor" ou "campo": literal).
    CLASS-METHODS extrair_campo
      IMPORTING iv_json         TYPE string
                iv_campo        TYPE string
      RETURNING VALUE(rv_valor) TYPE string.
ENDCLASS.



CLASS zcl_pc_viacep IMPLEMENTATION.

  METHOD consultar.
    DATA(lv_cep) = zcl_pc_util=>somente_digitos( iv_cep ).

    IF strlen( lv_cep ) <> 8.
      rs_resultado-valido        = abap_false.
      rs_resultado-mensagem_erro = `O CEP deve possuir exatamente 8 dígitos.`.
      RETURN.
    ENDIF.

    READ TABLE gt_cache INTO DATA(ls_cache) WITH KEY cep = lv_cep.
    IF sy-subrc = 0.
      rs_resultado = ls_cache-resultado.
      RETURN.
    ENDIF.

    rs_resultado = chamar_servico( lv_cep ).

    " Cache apenas para respostas definitivas (indisponibilidade não é cacheada)
    IF rs_resultado-indisponivel = abap_false.
      IF lines( gt_cache ) >= c_max_cache.
        DELETE gt_cache INDEX 1.
      ENDIF.
      APPEND VALUE #( cep = lv_cep resultado = rs_resultado ) TO gt_cache.
    ENDIF.
  ENDMETHOD.


  METHOD chamar_servico.
    DATA lo_cliente    TYPE REF TO if_http_client.
    DATA lv_status     TYPE i.
    DATA lv_motivo     TYPE string.
    DATA lv_json       TYPE string.
    DATA lv_erro_cod   TYPE i.
    DATA lv_erro_texto TYPE string.

    cl_http_client=>create_by_destination(
      EXPORTING  destination              = c_destination
      IMPORTING  client                   = lo_cliente
      EXCEPTIONS argument_not_found       = 1
                 destination_not_found    = 2
                 destination_no_authority = 3
                 plugin_not_active        = 4
                 internal_error           = 5
                 OTHERS                   = 6 ).

    IF sy-subrc <> 0 OR lo_cliente IS NOT BOUND.
      rs_resultado-indisponivel  = abap_true.
      rs_resultado-mensagem_erro = SWITCH #( sy-subrc
        WHEN 2 THEN |Destination { c_destination } não encontrada na SM59.|
        WHEN 3 THEN |Usuário sem autorização para a destination { c_destination }.|
        ELSE        |Não foi possível criar o cliente HTTP (sy-subrc { sy-subrc }).| ).
      RETURN.
    ENDIF.

    " Só o caminho variável fica no código; host, porta e SSL vêm da SM59
    cl_http_utility=>set_request_uri( request = lo_cliente->request
                                      uri     = |/ws/{ iv_cep }/json/| ).
    lo_cliente->request->set_method( if_http_request=>co_request_method_get ).
    lo_cliente->request->set_header_field( name = `Accept` value = `application/json` ).

    lo_cliente->send( EXPORTING  timeout                    = c_timeout
                      EXCEPTIONS http_communication_failure = 1
                                 http_invalid_state         = 2
                                 http_processing_failed     = 3
                                 http_invalid_timeout       = 4
                                 OTHERS                     = 5 ).
    IF sy-subrc = 0.
      lo_cliente->receive( EXCEPTIONS http_communication_failure = 1
                                      http_invalid_state         = 2
                                      http_processing_failed     = 3
                                      OTHERS                     = 4 ).
    ENDIF.

    IF sy-subrc <> 0.
      " Ex.: SSSLERR_PEER_CERT_UNTRUSTED (STRUST), proxy ou firewall bloqueando
      lo_cliente->get_last_error( IMPORTING code    = lv_erro_cod
                                            message = lv_erro_texto ).
      rs_resultado-indisponivel  = abap_true.
      rs_resultado-mensagem_erro = |Falha HTTP { lv_erro_cod }: { lv_erro_texto }|.
      " Fecha o cliente também em caso de erro (evita conexões abertas)
      lo_cliente->close( ).
      RETURN.
    ENDIF.

    lo_cliente->response->get_status( IMPORTING code   = lv_status
                                                reason = lv_motivo ).
    lv_json = lo_cliente->response->get_cdata( ).
    lo_cliente->close( ).

    rs_resultado-status_http = lv_status.

    CASE lv_status.
      WHEN 200.
        " segue para o parse
      WHEN 400 OR 404.
        " Formato inválido ou CEP inexistente segundo o ViaCEP
        rs_resultado-valido        = abap_false.
        rs_resultado-mensagem_erro = |CEP inválido ou não encontrado (HTTP { lv_status } { lv_motivo }).|.
        RETURN.
      WHEN OTHERS.
        " 408, 429, 5xx e respostas inesperadas: tratar como indisponível
        rs_resultado-indisponivel  = abap_true.
        rs_resultado-mensagem_erro = |Resposta HTTP { lv_status } { lv_motivo }.|.
        RETURN.
    ENDCASE.

    rs_resultado-endereco = VALUE #(
      cep         = extrair_campo( iv_json = lv_json iv_campo = `cep` )
      logradouro  = extrair_campo( iv_json = lv_json iv_campo = `logradouro` )
      complemento = extrair_campo( iv_json = lv_json iv_campo = `complemento` )
      bairro      = extrair_campo( iv_json = lv_json iv_campo = `bairro` )
      localidade  = extrair_campo( iv_json = lv_json iv_campo = `localidade` )
      uf          = extrair_campo( iv_json = lv_json iv_campo = `uf` )
      estado      = extrair_campo( iv_json = lv_json iv_campo = `estado` )
      erro        = extrair_campo( iv_json = lv_json iv_campo = `erro` ) ).

    " CEP inexistente: {"erro": true} ou {"erro": "true"}
    IF rs_resultado-endereco-erro IS NOT INITIAL
       OR rs_resultado-endereco-localidade IS INITIAL.
      rs_resultado-valido        = abap_false.
      rs_resultado-mensagem_erro = |CEP { iv_cep } não encontrado no ViaCEP.|.
      RETURN.
    ENDIF.

    rs_resultado-valido    = abap_true.
    rs_resultado-cep_geral = xsdbool( rs_resultado-endereco-logradouro IS INITIAL ).
  ENDMETHOD.


  METHOD extrair_campo.
    " Literais com backtick não interpretam escapes: o PCRE vai íntegro
    DATA(lv_pattern) = `"` && iv_campo && `"\s*:\s*(?:"([^"]*)"|([a-zA-Z]+))`.

    FIND PCRE lv_pattern IN iv_json SUBMATCHES DATA(lv_texto) DATA(lv_literal).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rv_valor = COND #( WHEN lv_texto IS NOT INITIAL THEN lv_texto
                       WHEN lv_literal = `null`     THEN ``
                       ELSE lv_literal ).
  ENDMETHOD.

ENDCLASS.
