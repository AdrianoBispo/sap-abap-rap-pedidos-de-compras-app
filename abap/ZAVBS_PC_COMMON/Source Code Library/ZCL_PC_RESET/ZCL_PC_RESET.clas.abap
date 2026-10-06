"! <p class="shorttext synchronized">Pedidos de Compras - Reset dos dados do banco</p>
"! APAGA todos os dados de negócio (clientes, endereços, itens de estoque,
"! pedidos, pagamentos, reembolsos e snapshots) e as tabelas draft de cada BO.
"! Executar no ADT com F9 (Run as ABAP Application - Console).
"!
"! Não toca em:
"!  - ZTA_PC_CODELIST (cadastro de listas; recarregada por ZCL_PC_SETUP);
"!  - intervalos do objeto de numeração ZPC_NR: o próximo pedido/SKU continua
"!    de onde parou (para recomeçar, zere os intervalos no ADT e rode ZCL_PC_SETUP).
"!
"! Proteção: só roda com ZIF_PC_CONSTANTS=>C_MODO_TRIAL = abap_true, o mesmo
"! indicador de ambiente educacional/demonstração usado em ZCL_PC_AUTH.
"! Depois do reset, ZCL_PC_SETUP recarrega os dados de demonstração.
CLASS zcl_pc_reset DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    TYPES:
      BEGIN OF ty_resultado,
        tabela    TYPE string,
        apagados  TYPE i,
      END OF ty_resultado.
    TYPES tt_resultado TYPE STANDARD TABLE OF ty_resultado WITH EMPTY KEY.

    "! Apaga os dados e confirma (COMMIT WORK). Devolve a quantidade apagada
    "! por tabela. Em ambiente que não é de demonstração não apaga nada.
    CLASS-METHODS resetar
      EXPORTING et_resultado TYPE tt_resultado
                ev_executado TYPE abap_boolean.

  PROTECTED SECTION.
  PRIVATE SECTION.
    "! Tabelas de dados, filhas antes das mães.
    CLASS-METHODS tabelas
      RETURNING VALUE(rt_tabelas) TYPE string_table.
ENDCLASS.



CLASS zcl_pc_reset IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    resetar( IMPORTING et_resultado = DATA(lt_resultado)
                       ev_executado = DATA(lv_executado) ).

    IF lv_executado = abap_false.
      out->write( `Reset recusado: o ambiente não está marcado como demonstração (ZIF_PC_CONSTANTS=>C_MODO_TRIAL).` ).
      RETURN.
    ENDIF.

    DATA(lv_total) = 0.
    LOOP AT lt_resultado INTO DATA(ls_res).
      out->write( |{ ls_res-tabela }: { ls_res-apagados } registro(s) apagado(s)| ).
      lv_total = lv_total + ls_res-apagados.
    ENDLOOP.
    out->write( |Reset concluído: { lv_total } registro(s) apagado(s) em { lines( lt_resultado ) } tabelas.| ).
    out->write( `Execute ZCL_PC_SETUP para recarregar os dados de demonstração.` ).
  ENDMETHOD.


  METHOD resetar.
    CLEAR: et_resultado, ev_executado.

    IF zif_pc_constants=>c_modo_trial = abap_false.
      RETURN.
    ENDIF.

    LOOP AT tabelas( ) INTO DATA(lv_tabela).
      SELECT COUNT( * ) FROM (lv_tabela) INTO @DATA(lv_qtd).
      DELETE FROM (lv_tabela).
      APPEND VALUE #( tabela = lv_tabela apagados = lv_qtd ) TO et_resultado.
    ENDLOOP.

    COMMIT WORK.
    ev_executado = abap_true.
  ENDMETHOD.


  METHOD tabelas.
    rt_tabelas = VALUE #(
      " Pedido (filhos primeiro) e suas tabelas draft
      ( `ZTA_PC_SNAP_ITM` ) ( `ZTA_PC_SNPITM_D` )
      ( `ZTA_PC_SNAP_CLI` ) ( `ZTA_PC_SNPCLI_D` )
      ( `ZTA_PC_PAGAMENTO` ) ( `ZTA_PC_PAGTO_D` )
      ( `ZTA_PC_ITEM_PED` ) ( `ZTA_PC_ITPED_D` )
      ( `ZTA_PC_PEDIDO` ) ( `ZTA_PC_PEDIDO_D` )
      " Reembolso
      ( `ZTA_PC_REEMBOLSO` ) ( `ZTA_PC_REEMB_D` )
      " Estoque
      ( `ZTA_PC_ITEM` ) ( `ZTA_PC_ITEM_D` )
      " Clientes
      ( `ZTA_PC_ENDERECO` ) ( `ZTA_PC_ENDEREC_D` )
      ( `ZTA_PC_CLIENTE` ) ( `ZTA_PC_CLIENTE_D` ) ).
  ENDMETHOD.

ENDCLASS.
