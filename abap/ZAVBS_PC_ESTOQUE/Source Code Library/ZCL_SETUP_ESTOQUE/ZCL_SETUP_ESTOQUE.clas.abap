"! <p class="shorttext synchronized">Pedidos de Compras - Carga de estoque de demonstração</p>
"! Insere 100 itens (25 produtos-base x 4 linhas) com SKU gerado pela numeração.
"! Estoque variado: 5 itens sem estoque, 5 acabando e os demais em estoque.
"! Pode ser executada mais de uma vez: itens com o mesmo nome são ignorados.
CLASS zcl_setup_estoque DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_quantidade TYPE i VALUE 100.

    METHODS carregar_dados
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out
      RAISING   cx_uuid_error cx_number_ranges.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_base,
        nome      TYPE zta_pc_item-nome,
        descricao TYPE zta_pc_item-descricao,
        categoria TYPE zta_pc_item-categoria,
        preco     TYPE zta_pc_item-preco_unitario,
      END OF ty_base.
    TYPES:
      BEGIN OF ty_variante,
        nome  TYPE string,
        fator TYPE p LENGTH 3 DECIMALS 2,
      END OF ty_variante.
ENDCLASS.



CLASS zcl_setup_estoque IMPLEMENTATION.

  METHOD carregar_dados.
    DATA lv_agora TYPE timestampl.
    GET TIME STAMP FIELD lv_agora.

    DATA(lv_usuario) = CONV abp_creation_user( 'SETUP' ).
    TRY.
        lv_usuario = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        " mantém 'SETUP'
    ENDTRY.

    DATA lt_base      TYPE STANDARD TABLE OF ty_base WITH EMPTY KEY.
    DATA lt_variantes TYPE STANDARD TABLE OF ty_variante WITH EMPTY KEY.
    DATA lt_itens     TYPE STANDARD TABLE OF zta_pc_item WITH EMPTY KEY.

    lt_base = VALUE #(
      ( nome = `Notebook 14 polegadas`   descricao = `Notebook para uso profissional`    categoria = 'INFORMATICA' preco = '3499.90' )
      ( nome = `Mouse sem fio`           descricao = `Mouse óptico sem fio`              categoria = 'INFORMATICA' preco = '89.90' )
      ( nome = `Teclado mecânico`        descricao = `Teclado mecânico ABNT2`            categoria = 'INFORMATICA' preco = '349.90' )
      ( nome = `Monitor 24 polegadas`    descricao = `Monitor Full HD`                   categoria = 'INFORMATICA' preco = '899.00' )
      ( nome = `Webcam Full HD`          descricao = `Webcam com microfone embutido`     categoria = 'INFORMATICA' preco = '219.90' )
      ( nome = `Fone Bluetooth`          descricao = `Fone de ouvido Bluetooth`          categoria = 'ELETRONICOS' preco = '199.00' )
      ( nome = `Caixa de som portátil`   descricao = `Caixa de som Bluetooth à prova d'água` categoria = 'ELETRONICOS' preco = '259.90' )
      ( nome = `Smartwatch`              descricao = `Relógio inteligente com GPS`       categoria = 'ELETRONICOS' preco = '599.00' )
      ( nome = `Carregador USB-C 65W`    descricao = `Carregador rápido USB-C`           categoria = 'ELETRONICOS' preco = '129.90' )
      ( nome = `Tablet 10 polegadas`     descricao = `Tablet para estudo e trabalho`     categoria = 'ELETRONICOS' preco = '1499.00' )
      ( nome = `Cadeira de escritório`   descricao = `Cadeira ergonômica`                categoria = 'ESCRITORIO'  preco = '899.00' )
      ( nome = `Mesa de escritório`      descricao = `Mesa com gaveteiro`                categoria = 'ESCRITORIO'  preco = '649.00' )
      ( nome = `Luminária de mesa LED`   descricao = `Luminária com ajuste de intensidade` categoria = 'ESCRITORIO' preco = '79.90' )
      ( nome = `Agenda planejador`       descricao = `Agenda anual com capa dura`        categoria = 'ESCRITORIO'  preco = '39.90' )
      ( nome = `Organizador de mesa`     descricao = `Organizador multiuso de mesa`      categoria = 'ESCRITORIO'  preco = '49.90' )
      ( nome = `Jogo de panelas`         descricao = `Jogo de panelas antiaderentes`     categoria = 'CASA'        preco = '399.90' )
      ( nome = `Aspirador de pó`         descricao = `Aspirador de pó vertical`          categoria = 'CASA'        preco = '459.00' )
      ( nome = `Conjunto de toalhas`     descricao = `Conjunto de toalhas de algodão`    categoria = 'CASA'        preco = '119.90' )
      ( nome = `Almofada decorativa`     descricao = `Almofada decorativa para sofá`     categoria = 'CASA'        preco = '59.90' )
      ( nome = `Ventilador de mesa`      descricao = `Ventilador silencioso 3 velocidades` categoria = 'CASA'      preco = '189.90' )
      ( nome = `Camiseta de algodão`     descricao = `Camiseta básica de algodão`        categoria = 'VESTUARIO'   preco = '69.90' )
      ( nome = `Tênis esportivo`         descricao = `Tênis para corrida`                categoria = 'VESTUARIO'   preco = '329.90' )
      ( nome = `Jaqueta corta-vento`     descricao = `Jaqueta leve corta-vento`          categoria = 'VESTUARIO'   preco = '249.90' )
      ( nome = `Café especial 500g`      descricao = `Café torrado e moído`              categoria = 'ALIMENTOS'   preco = '42.90' )
      ( nome = `Garrafa térmica`         descricao = `Garrafa térmica de aço inox`       categoria = 'OUTROS'      preco = '79.90' ) ).

    lt_variantes = VALUE #(
      ( nome = `Básico`   fator = '1.00' )
      ( nome = `Standard` fator = '1.15' )
      ( nome = `Plus`     fator = '1.30' )
      ( nome = `Premium`  fator = '1.50' ) ).

    SELECT nome FROM zta_pc_item INTO TABLE @DATA(lt_nomes_existentes).

    DO c_quantidade TIMES.
      DATA(lv_i) = sy-index - 1.

      DATA(ls_base)     = lt_base[ lv_i MOD lines( lt_base ) + 1 ].
      DATA(ls_variante) = lt_variantes[ lv_i DIV lines( lt_base ) + 1 ].
      DATA(lv_nome)     = CONV zta_pc_item-nome( |{ ls_base-nome } { ls_variante-nome }| ).

      IF line_exists( lt_nomes_existentes[ nome = lv_nome ] ).
        CONTINUE.
      ENDIF.

      " 5 itens sem estoque, 5 acabando (1-10), demais em estoque (>= 11)
      DATA(lv_estoque) = COND i( WHEN lv_i MOD 20 = 0 THEN 0
                                 WHEN lv_i MOD 20 = 7 THEN 5
                                 ELSE 40 + ( lv_i * 13 ) MOD 160 ).

      APPEND VALUE #( item_uuid             = cl_system_uuid=>create_uuid_x16_static( )
                      sku                   = zcl_pc_numeracao=>gerar_sku( ls_base-categoria )
                      nome                  = lv_nome
                      descricao             = |{ ls_base-descricao } - linha { ls_variante-nome }|
                      categoria             = ls_base-categoria
                      qtde_estoque          = lv_estoque
                      qtde_reservada        = 0
                      qtde_disponivel       = lv_estoque
                      status_estoque        = zcl_pc_util=>calcular_status_estoque( lv_estoque )
                      currency              = zif_pc_constants=>c_moeda_padrao
                      preco_unitario        = ls_base-preco * ls_variante-fator
                      item_ativo            = abap_true
                      created_by            = lv_usuario
                      created_at            = lv_agora
                      last_changed_by       = lv_usuario
                      last_changed_at       = lv_agora
                      local_last_changed_at = lv_agora ) TO lt_itens.
    ENDDO.

    IF lt_itens IS INITIAL.
      io_out->write( `Itens de estoque de demonstração já carregados: nada a inserir.` ).
      RETURN.
    ENDIF.

    INSERT zta_pc_item FROM TABLE @lt_itens.

    io_out->write( |Itens de estoque de demonstração criados: { lines( lt_itens ) }.| ).
  ENDMETHOD.

ENDCLASS.
