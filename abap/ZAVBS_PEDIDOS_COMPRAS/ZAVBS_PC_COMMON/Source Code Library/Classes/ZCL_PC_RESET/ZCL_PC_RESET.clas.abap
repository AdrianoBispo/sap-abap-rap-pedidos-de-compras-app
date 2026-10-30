"! <strong>Reset dos dados:</strong>
"! APAGA todos os dados de negócio (clientes, endereços, itens de estoque,
"! pedidos, pagamentos, reembolsos e snapshots) e as tabelas draft de cada BO.
"! Contudo, só roda quando <strong>{@link ZIF_PC_CONSTANTS.data:C_MODO_TRIAL} = abap_true</strong>,
"! o mesmo indicador de ambiente de demonstração usado em {@link ZCL_PC_AUTH}.
"!
"! <p>Ficam de fora do reset:</p>
"! <ul>
"!  <li>{@link ZTA_PC_CODELIST} que pode ser recarregada por {@link ZCL_PC_SETUP};</li>
"!  <li>Intervalos do objeto de numeração {@link ZPC_NR}. O próximo pedido/SKU continuam
"!   de onde parou. Caso queira recomeçar, zere os intervalos e rode {@link ZCL_PC_SETUP}.</li>
"! </ul>
"!
"! <p>Constantes, tipos e métodos públicos são declarados na interface {@link ZIF_PC_RESET}.</p>
CLASS zcl_pc_reset DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    INTERFACES zif_pc_reset.

    ALIASES resetar FOR zif_pc_reset~resetar.

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


  METHOD zif_pc_reset~resetar.

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
