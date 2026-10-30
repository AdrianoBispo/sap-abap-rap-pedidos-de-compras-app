"! <h1>Interface para Objetos Utilitários</h1>
"! Interface onde é declarada as constantes, tipos e métodos públicos da classe {@link ZCL_PC_UTIL}
INTERFACE zif_pc_util PUBLIC.

  "! Remove tudo que não for dígito (CPF, CEP, telefone, cartão).
  CLASS-METHODS somente_digitos
    IMPORTING iv_valor        TYPE csequence
    RETURNING VALUE(rv_valor) TYPE string.

  "! Valida CPF: 11 dígitos, não repetidos e dígitos verificadores.
  CLASS-METHODS validar_cpf
    IMPORTING iv_cpf           TYPE csequence
    RETURNING VALUE(rv_valido) TYPE abap_boolean.

  "! Calcula os 2 dígitos verificadores para uma base de 9 dígitos.
  CLASS-METHODS calcular_dv_cpf
    IMPORTING iv_base9      TYPE csequence
    RETURNING VALUE(rv_cpf) TYPE string.

  "! Formata CPF (somente dígitos) como 000.000.000-00.
  CLASS-METHODS formatar_cpf
    IMPORTING iv_cpf              TYPE csequence
    RETURNING VALUE(rv_formatado) TYPE string.

  "! Formata telefone (10/11 dígitos) como (00) 00000-0000.
  CLASS-METHODS formatar_telefone
    IMPORTING iv_telefone         TYPE csequence
    RETURNING VALUE(rv_formatado) TYPE string.

  CLASS-METHODS validar_email
    IMPORTING iv_email         TYPE csequence
    RETURNING VALUE(rv_valido) TYPE abap_boolean.

  "! Aceita somente JPEG/PNG/WEBP: MIME type, extensão e assinatura binária.
  "! Conteúdo vazio é considerado válido (foto opcional).
  CLASS-METHODS validar_imagem
    IMPORTING iv_conteudo      TYPE xstring
              iv_mime_type     TYPE csequence
              iv_nome_arquivo  TYPE csequence
    RETURNING VALUE(rv_valida) TYPE abap_boolean.

  "! SEM_ESTOQUE (0), ACABANDO (1-10) ou EM_ESTOQUE (>= 11).
  CLASS-METHODS calcular_status_estoque
    IMPORTING iv_qtde_disponivel TYPE i
    RETURNING VALUE(rv_status)   TYPE zif_pc_constants=>ty_status_estoque.

  CLASS-METHODS formatar_endereco
    IMPORTING iv_logradouro      TYPE csequence
              iv_numero          TYPE csequence
              iv_complemento     TYPE csequence OPTIONAL
              iv_bairro          TYPE csequence
              iv_cidade          TYPE csequence
              iv_uf              TYPE csequence
              iv_cep             TYPE csequence
    RETURNING VALUE(rv_endereco) TYPE string.

ENDINTERFACE.