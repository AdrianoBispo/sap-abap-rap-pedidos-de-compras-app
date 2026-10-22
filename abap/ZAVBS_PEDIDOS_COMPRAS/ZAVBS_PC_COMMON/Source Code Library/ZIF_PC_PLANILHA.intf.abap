"! <p class="shorttext synchronized">Pedidos de Compras - Leitura de planilhas (XLSX/CSV)</p>
"! Constantes, tipos e métodos públicos de ZCL_PC_PLANILHA, que implementa esta interface.
INTERFACE zif_pc_planilha PUBLIC.

  CONSTANTS c_max_linhas TYPE i VALUE 500.

  TYPES:
    BEGIN OF ty_coluna,
      campo       TYPE string,
      sinonimos   TYPE string,
      obrigatoria TYPE abap_boolean,
    END OF ty_coluna.
  TYPES tt_colunas TYPE STANDARD TABLE OF ty_coluna WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_valor,
      campo TYPE string,
      valor TYPE string,
    END OF ty_valor.
  TYPES tt_valores TYPE HASHED TABLE OF ty_valor WITH UNIQUE KEY campo.

  TYPES:
    BEGIN OF ty_registro,
      linha   TYPE i,
      valores TYPE tt_valores,
    END OF ty_registro.
  TYPES tt_registros TYPE STANDARD TABLE OF ty_registro WITH EMPTY KEY.

  TYPES tt_matriz TYPE STANDARD TABLE OF string_table WITH EMPTY KEY.

  "! Lê o arquivo e devolve os registros (linhas de dados) já associados às
  "! colunas pedidas. Em ET_ERROS vêm os problemas de leitura/cabeçalho; se
  "! houver algum, ET_REGISTROS fica vazio.
  "! O texto de cada coluna em IT_COLUNAS-CAMPO é o nome de acesso em VALOR( ).
  "! IT_COLUNAS-SINONIMOS: nomes alternativos já normalizados, separados por |.
  CLASS-METHODS ler
    IMPORTING iv_conteudo  TYPE xstring
              it_colunas   TYPE tt_colunas
    EXPORTING et_registros TYPE tt_registros
              et_erros     TYPE string_table.

  "! Valor (aparado) da coluna no registro; vazio se a coluna não existir.
  CLASS-METHODS valor
    IMPORTING is_registro     TYPE ty_registro
              iv_campo        TYPE csequence
    RETURNING VALUE(rv_valor) TYPE string.

  "! Maiúsculas, sem acentos e só A-Z/0-9 (comparação de cabeçalhos).
  CLASS-METHODS normalizar
    IMPORTING iv_texto        TYPE csequence
    RETURNING VALUE(rv_texto) TYPE string.

  "! CSV -> matriz de células (uma linha por linha do arquivo, vazias inclusive).
  CLASS-METHODS ler_csv
    IMPORTING iv_conteudo TYPE xstring
    EXPORTING et_matriz   TYPE tt_matriz
              ev_erro     TYPE string.

  "! Data em ISO (2024-05-31), brasileira (31/05/2024), AAAAMMDD ou número
  "! serial do Excel. Inicial se não for uma data válida.
  CLASS-METHODS para_data
    IMPORTING iv_texto       TYPE csequence
    RETURNING VALUE(rv_data) TYPE d.

  "! Número com ponto ou vírgula decimal, sem separador de milhar
  "! (se houver ponto e vírgula, o último é o decimal).
  CLASS-METHODS para_decimal
    IMPORTING iv_texto  TYPE csequence
    EXPORTING ev_valor  TYPE decfloat34
              ev_valido TYPE abap_boolean.

  "! Número inteiro (aceita 10, 10.0 ou 10,00).
  CLASS-METHODS para_inteiro
    IMPORTING iv_texto  TYPE csequence
    EXPORTING ev_valor  TYPE i
              ev_valido TYPE abap_boolean.

ENDINTERFACE.