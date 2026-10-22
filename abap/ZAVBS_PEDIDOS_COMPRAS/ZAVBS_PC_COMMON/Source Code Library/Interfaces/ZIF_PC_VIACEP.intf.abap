"! <p class="shorttext synchronized">Pedidos de Compras - Consulta de CEP (ViaCEP)</p>
"! Constantes, tipos e métodos públicos de ZCL_PC_VIACEP, comuns às duas versões
"! da classe (pasta ZCL_PC_VIACEP: SAP BTP; pasta ZCL_PC_VIACEP_T2: On-Premise).
"! STATUS_HTTP e MENSAGEM_ERRO só são preenchidos pela versão On-Premise.
INTERFACE zif_pc_viacep PUBLIC.

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

  "! Consulta o CEP (8 dígitos). Resultados definitivos ficam em cache por
  "! sessão (limitado a c_max_cache entradas) para evitar chamadas repetidas.
  CLASS-METHODS consultar
    IMPORTING iv_cep              TYPE csequence
    RETURNING VALUE(rs_resultado) TYPE ty_resultado.

ENDINTERFACE.