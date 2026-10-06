CLASS ltcl_importacao DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS xstr
      IMPORTING iv_texto      TYPE string
      RETURNING VALUE(rv_hex) TYPE xstring.

    METHODS importar_clientes
      IMPORTING iv_csv    TYPE string
      EXPORTING ev_falhou TYPE abap_boolean
                ev_texto  TYPE string.

    METHODS normalizar_cpf_cep   FOR TESTING.
    METHODS codelist_por_texto   FOR TESTING.
    METHODS resumo_de_erros      FOR TESTING.
    METHODS cliente_valido       FOR TESTING.
    METHODS cliente_cpf_invalido FOR TESTING.
    METHODS cliente_cpf_repetido FOR TESTING.
    METHODS cliente_sem_coluna   FOR TESTING.
    METHODS cliente_xlsx_vazio   FOR TESTING.
    METHODS tamanho_mensagem     FOR TESTING.

    METHODS importar_itens
      IMPORTING iv_csv    TYPE string
      EXPORTING ev_falhou TYPE abap_boolean
                ev_texto  TYPE string.
    METHODS item_valido          FOR TESTING.
    METHODS item_valores_ruins   FOR TESTING.
    METHODS item_nome_repetido   FOR TESTING.

    METHODS importar_pedidos
      IMPORTING iv_csv    TYPE string
      EXPORTING ev_falhou TYPE abap_boolean
                ev_texto  TYPE string.
    METHODS dados_base
      EXPORTING ev_cpf    TYPE string
                ev_sku    TYPE string
                ev_existe TYPE abap_boolean.
    METHODS pedido_valido          FOR TESTING.
    METHODS pedido_dois_pedidos    FOR TESTING.
    METHODS pedido_erros_de_linha  FOR TESTING.
    METHODS pedido_cpfs_diferentes FOR TESTING.
    METHODS pedido_sem_estoque     FOR TESTING.
ENDCLASS.


CLASS ltcl_importacao IMPLEMENTATION.

  METHOD xstr.
    rv_hex = cl_abap_conv_codepage=>create_out( codepage = 'UTF-8' )->convert( source = iv_texto ).
  ENDMETHOD.

  METHOD importar_clientes.
    MODIFY ENTITIES OF zr_pc_cliente
      ENTITY Cliente
        EXECUTE ImportarPlanilha
        FROM VALUE #( ( %cid   = 'IMP1'
                        %param = VALUE #( _streamproperties = VALUE #( streamproperty = xstr( iv_csv ) ) ) ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    ev_falhou = xsdbool( ls_failed-cliente IS NOT INITIAL ).
    CLEAR ev_texto.
    LOOP AT ls_reported-cliente INTO DATA(ls_rep) WHERE %msg IS BOUND.
      ev_texto = |{ ev_texto } / { ls_rep-%msg->if_message~get_text( ) }|.
    ENDLOOP.
  ENDMETHOD.

  METHOD normalizar_cpf_cep.
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>normalizar_cpf( `529.982.247-25` ) exp = `52998224725` ).
    " O Excel guarda CPF como número e perde os zeros à esquerda
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>normalizar_cpf( `1234567890` ) exp = `01234567890` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>normalizar_cpf( `` ) exp = `` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>normalizar_cep( `01001-000` ) exp = `01001000` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>normalizar_cep( `1001000` ) exp = `01001000` ).
  ENDMETHOD.

  METHOD codelist_por_texto.
    " Depende da CodeList carregada por ZCL_PC_SETUP
    SELECT SINGLE @abap_true FROM zr_pc_codelist
      WHERE Lista = @zif_pc_constants=>c_codelist-genero
      INTO @DATA(lv_existe).
    IF lv_existe = abap_false.
      RETURN.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>converter_codelist( iv_lista = 'GENERO' iv_texto = `feminino` )
                                        exp = `FEMININO` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>converter_codelist( iv_lista = 'GENERO' iv_texto = `Não binário` )
                                        exp = `NAO_BINARIO` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_pc_importacao=>converter_codelist( iv_lista = 'GENERO' iv_texto = `NAO_BINARIO` )
                                        exp = `NAO_BINARIO` ).
    cl_abap_unit_assert=>assert_initial( act = zcl_pc_importacao=>converter_codelist( iv_lista = 'GENERO' iv_texto = `xyz` ) ).
    cl_abap_unit_assert=>assert_initial( act = zcl_pc_importacao=>converter_codelist( iv_lista = 'GENERO' iv_texto = `` ) ).
  ENDMETHOD.

  METHOD resumo_de_erros.
    DATA lt_erros TYPE string_table.
    DO zcl_pc_importacao=>c_max_erros_exibidos + 5 TIMES.
      APPEND |erro { sy-index }| TO lt_erros.
    ENDDO.
    DATA(lt_resumo) = zcl_pc_importacao=>resumir_erros( lt_erros ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_resumo ) exp = zcl_pc_importacao=>c_max_erros_exibidos + 1 ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lt_resumo[ lines( lt_resumo ) ] CS `mais 5` ) ).

    DATA(lt_curto) = zcl_pc_importacao=>resumir_erros( VALUE #( ( `a` ) ( `b` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_curto ) exp = 2 ).
  ENDMETHOD.

  METHOD cliente_valido.
    importar_clientes(
      EXPORTING iv_csv = |CPF;Nome;E-mail;Telefone;Gênero;Data de nascimento;CEP;Número;Complemento\n| &&
                         |12345678909;Maria Teste;maria.teste@example.com;11987654321;Feminino;15/04/1990;01001-000;100;Sala 1\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = |Importação válida não deveria falhar: { lv_texto }| ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `1 cliente(s) criado(s)` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD cliente_cpf_invalido.
    importar_clientes(
      EXPORTING iv_csv = |CPF;Nome;E-mail;Telefone;Data de nascimento;CEP;Número\n| &&
                         |11111111111;Ana;ana@example.com;11987654321;1990-01-01;01001000;10\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_true( act = lv_falhou ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 2` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `CPF inválido` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `nenhum cliente foi gravado` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD cliente_cpf_repetido.
    importar_clientes(
      EXPORTING iv_csv = |CPF;Nome;E-mail;Telefone;Data de nascimento;CEP;Número\n| &&
                         |12345678909;Ana;ana@example.com;11987654321;1990-01-01;01001000;10\n| &&
                         |123.456.789-09;Bia;bia@example.com;11987654321;1991-02-02;01001000;20\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_true( act = lv_falhou ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `repetido na planilha` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD cliente_sem_coluna.
    importar_clientes(
      EXPORTING iv_csv = |CPF;Nome\n52998224725;Ana\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_true( act = lv_falhou ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Coluna obrigatória não encontrada` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD importar_itens.
    MODIFY ENTITIES OF zr_pc_item
      ENTITY Item
        EXECUTE ImportarPlanilha
        FROM VALUE #( ( %cid   = 'IMP1'
                        %param = VALUE #( _streamproperties = VALUE #( streamproperty = xstr( iv_csv ) ) ) ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    ev_falhou = xsdbool( ls_failed-item IS NOT INITIAL ).
    CLEAR ev_texto.
    LOOP AT ls_reported-item INTO DATA(ls_rep) WHERE %msg IS BOUND.
      ev_texto = |{ ev_texto } / { ls_rep-%msg->if_message~get_text( ) }|.
    ENDLOOP.
  ENDMETHOD.

  METHOD item_valido.
    " Depende das CodeLists carregadas por ZCL_PC_SETUP
    SELECT SINGLE @abap_true FROM zr_pc_codelist
      WHERE Lista = @zif_pc_constants=>c_codelist-categoria
      INTO @DATA(lv_existe).
    IF lv_existe = abap_false.
      RETURN.
    ENDIF.

    " Preço com vírgula, categoria pelo nome (com acento) e moeda omitida
    importar_itens(
      EXPORTING iv_csv = |Nome;Descrição;Categoria;Quantidade em estoque;Preço unitário;Moeda\n| &&
                         |Item QA Importação;Descrição qualquer;Informática;25;1.499,90;\n| &&
                         |Item QA Importação 2;;ELETRONICOS;0;89,9;BRL\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = |Importação válida não deveria falhar: { lv_texto }| ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `2 item(ns) criado(s)` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD item_valores_ruins.
    importar_itens(
      EXPORTING iv_csv = |Nome;Categoria;Quantidade em estoque;Preço unitário\n| &&
                         |Item A;Inexistente;5;10\n| &&
                         |Item B;Informática;-3;10\n| &&
                         |Item C;Informática;2,5;10\n| &&
                         |Item D;Informática;5;abc\n| &&
                         |;Informática;5;10\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_true( act = lv_falhou ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 2: Categoria inválida` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 3: Quantidade em estoque inválida` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 4: Quantidade em estoque inválida` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 5: Preço unitário inválido` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 6: Nome é obrigatório` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `nenhum item foi gravado` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD item_nome_repetido.
    importar_itens(
      EXPORTING iv_csv = |Nome;Categoria;Quantidade em estoque;Preço unitário\n| &&
                         |Mesmo Nome;Informática;5;10\n| &&
                         |mesmo nome;Informática;6;11\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_true( act = lv_falhou ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `repetido na planilha` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD importar_pedidos.
    MODIFY ENTITIES OF zr_pc_pedido
      ENTITY Pedido
        EXECUTE ImportarPlanilha
        FROM VALUE #( ( %cid   = 'IMP1'
                        %param = VALUE #( _streamproperties = VALUE #( streamproperty = xstr( iv_csv ) ) ) ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    ev_falhou = xsdbool( ls_failed-pedido IS NOT INITIAL ).
    CLEAR ev_texto.
    LOOP AT ls_reported-pedido INTO DATA(ls_rep) WHERE %msg IS BOUND.
      ev_texto = |{ ev_texto } / { ls_rep-%msg->if_message~get_text( ) }|.
    ENDLOOP.
  ENDMETHOD.

  METHOD dados_base.
    " Um cliente ativo com endereço principal e um item com saldo, já cadastrados
    CLEAR: ev_cpf, ev_sku, ev_existe.
    SELECT SINGLE c~cpf
      FROM zta_pc_cliente AS c
      INNER JOIN zta_pc_endereco AS e ON e~cliente_uuid = c~cliente_uuid
      WHERE c~cliente_ativo = @abap_true
        AND e~endereco_principal = @abap_true
      INTO @DATA(lv_cpf).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    SELECT SINGLE sku FROM zta_pc_item
      WHERE item_ativo = @abap_true AND qtde_disponivel > 1
      INTO @DATA(lv_sku).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ev_cpf    = lv_cpf.
    ev_sku    = lv_sku.
    ev_existe = abap_true.
  ENDMETHOD.

  METHOD pedido_valido.
    dados_base( IMPORTING ev_cpf = DATA(lv_cpf) ev_sku = DATA(lv_sku) ev_existe = DATA(lv_existe) ).
    IF lv_existe = abap_false.
      RETURN.
    ENDIF.

    " Duas linhas do mesmo pedido (itens repetidos são somados no estoque)
    importar_pedidos(
      EXPORTING iv_csv = |Pedido;CPF;SKU;Quantidade;Observação\n| &&
                         |P1;{ lv_cpf };{ lv_sku };1;Entregar na portaria\n| &&
                         |P1;{ lv_cpf };{ lv_sku };1;\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = |Importação válida não deveria falhar: { lv_texto }| ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `1 pedido(s) criado(s)` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `2 item(ns)` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD pedido_dois_pedidos.
    dados_base( IMPORTING ev_cpf = DATA(lv_cpf) ev_sku = DATA(lv_sku) ev_existe = DATA(lv_existe) ).
    IF lv_existe = abap_false.
      RETURN.
    ENDIF.

    importar_pedidos(
      EXPORTING iv_csv = |Pedido,CPF,SKU,Quantidade\n| &&
                         |A,{ lv_cpf },{ lv_sku },1\n| &&
                         |B,{ lv_cpf },{ to_lower( lv_sku ) },1\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_false( act = lv_falhou msg = |Importação válida não deveria falhar: { lv_texto }| ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `2 pedido(s) criado(s)` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD pedido_erros_de_linha.
    dados_base( IMPORTING ev_cpf = DATA(lv_cpf) ev_sku = DATA(lv_sku) ev_existe = DATA(lv_existe) ).
    IF lv_existe = abap_false.
      RETURN.
    ENDIF.

    importar_pedidos(
      EXPORTING iv_csv = |Pedido;CPF;SKU;Quantidade\n| &&
                         |;{ lv_cpf };{ lv_sku };1\n| &&
                         |P2;12345678909;{ lv_sku };1\n| &&
                         |P3;{ lv_cpf };NAO-EXISTE;1\n| &&
                         |P4;{ lv_cpf };{ lv_sku };0\n| &&
                         |P5;111;{ lv_sku };1\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_true( act = lv_falhou ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 2: Pedido` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 3: CPF` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 4: SKU NAO-EXISTE não encontrado` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 5: Quantidade inválida` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Linha 6: CPF inválido` ) msg = lv_texto ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `nenhum pedido foi gravado` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD pedido_cpfs_diferentes.
    dados_base( IMPORTING ev_cpf = DATA(lv_cpf) ev_sku = DATA(lv_sku) ev_existe = DATA(lv_existe) ).
    IF lv_existe = abap_false.
      RETURN.
    ENDIF.

    importar_pedidos(
      EXPORTING iv_csv = |Pedido;CPF;SKU;Quantidade\n| &&
                         |X;{ lv_cpf };{ lv_sku };1\n| &&
                         |X;12345678909;{ lv_sku };1\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_true( act = lv_falhou ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `CPFs diferentes` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD pedido_sem_estoque.
    dados_base( IMPORTING ev_cpf = DATA(lv_cpf) ev_sku = DATA(lv_sku) ev_existe = DATA(lv_existe) ).
    IF lv_existe = abap_false.
      RETURN.
    ENDIF.

    importar_pedidos(
      EXPORTING iv_csv = |Pedido;CPF;SKU;Quantidade\n| &&
                         |Z;{ lv_cpf };{ lv_sku };99999999\n|
      IMPORTING ev_falhou = DATA(lv_falhou)
                ev_texto  = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_true( act = lv_falhou ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `estoque insuficiente` ) msg = lv_texto ).
  ENDMETHOD.

  METHOD tamanho_mensagem.
    DATA(lv_longo) = |Linha 12: Data de nascimento inválida (xyz). Use AAAA-MM-DD ou DD/MM/AAAA, por favor revise.|.
    " Cada variável T100 comporta 50 caracteres: o texto livre usa 4 blocos (ZPC_MSG 049)
    DATA(lv_lido) = zcx_pc_msg=>texto( lv_longo )->if_message~get_text( ).
    cl_abap_unit_assert=>assert_equals( act = lv_lido exp = lv_longo
                                        msg = |Texto devolvido ({ strlen( lv_lido ) } de { strlen( lv_longo ) } caracteres)| ).
    cl_abap_unit_assert=>assert_equals( act = zcx_pc_msg=>texto( `curto` )->if_message~get_text( ) exp = `curto` ).
    " Acima de 200 caracteres o excedente é cortado
    DATA(lv_gigante) = repeat( val = `x` occ = 250 ).
    cl_abap_unit_assert=>assert_equals( act = strlen( zcx_pc_msg=>texto( lv_gigante )->if_message~get_text( ) ) exp = 200 ).
  ENDMETHOD.

  METHOD cliente_xlsx_vazio.
    importar_clientes( EXPORTING iv_csv = `` IMPORTING ev_falhou = DATA(lv_falhou) ev_texto = DATA(lv_texto) ).
    cl_abap_unit_assert=>assert_true( act = lv_falhou ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_texto CS `Nenhum arquivo` ) msg = lv_texto ).
  ENDMETHOD.

ENDCLASS.
