"! <p class="shorttext synchronized">Pedidos de Compras - Apoio à importação de planilhas</p>
"! Constantes, tipos e métodos públicos de ZCL_PC_IMPORTACAO, que implementa esta interface.
INTERFACE zif_pc_importacao PUBLIC.

  CONSTANTS c_max_erros_exibidos TYPE i VALUE 15.

  "! Somente dígitos, completando com zeros à esquerda até 11 (o Excel
  "! guarda CPF como número e perde os zeros iniciais).
  CLASS-METHODS normalizar_cpf
    IMPORTING iv_texto      TYPE csequence
    RETURNING VALUE(rv_cpf) TYPE string.

  "! Somente dígitos, completando com zeros à esquerda até 8.
  CLASS-METHODS normalizar_cep
    IMPORTING iv_texto      TYPE csequence
    RETURNING VALUE(rv_cep) TYPE string.

  "! Código da CodeList cujo código OU descrição (sem acento/caixa) bate com
  "! o texto. Vazio se o texto estiver vazio ou não existir na lista.
  CLASS-METHODS converter_codelist
    IMPORTING iv_lista         TYPE csequence
              iv_texto         TYPE csequence
    RETURNING VALUE(rv_codigo) TYPE string.

  "! Descrições da CodeList, para citar as opções válidas numa mensagem.
  CLASS-METHODS opcoes_codelist
    IMPORTING iv_lista        TYPE csequence
    RETURNING VALUE(rv_texto) TYPE string.

  "! Limita a lista a C_MAX_ERROS_EXIBIDOS itens e acrescenta o total omitido.
  CLASS-METHODS resumir_erros
    IMPORTING it_erros        TYPE string_table
    RETURNING VALUE(rt_erros) TYPE string_table.

ENDINTERFACE.