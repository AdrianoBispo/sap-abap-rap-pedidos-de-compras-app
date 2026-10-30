"! <h1>Interface para Consulta de CEP (ViaCEP)</h1>
"! Interface onde é declarada as constantes, tipos e métodos públicos da classe {@link ZCL_PC_VIACEP}
INTERFACE zif_pc_viacep PUBLIC.

  TYPES:
    "! Define a estrutura dos campos de endereço que será utilizado para armazenar os dados retornados pela API ViaCEP. <br/>
    "! Todos os campos estão definidos como campos do tipo string para serem compativeis com os tipos dos dados de retorno da API.
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

    "! Estrutura que lida com a resposta da API ViaCEP
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

      "! Recebe os dados de endereço retornados pela API ViaCEP se a consulta foi um sucesso
      endereco      TYPE ty_endereco,
    END OF ty_resultado.

  "! Consulta o CEP (somente os 8 dígitos numericos). Resultados definitivos ficam em cache por
  "! sessão limitado ao limite máximo ({@link ZCL_PC_VIACEP.DATA:c_max_cache}) para evitar chamadas repetidas.
  CLASS-METHODS consultar
    IMPORTING iv_cep              TYPE csequence
    RETURNING VALUE(rs_resultado) TYPE ty_resultado.

ENDINTERFACE.