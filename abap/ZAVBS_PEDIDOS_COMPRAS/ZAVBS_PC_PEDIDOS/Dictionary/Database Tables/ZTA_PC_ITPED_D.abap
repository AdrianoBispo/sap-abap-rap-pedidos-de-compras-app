@EndUserText.label : 'Draft table for entity ZR_PC_ITEM_PEDIDO'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_itped_d {

  key mandt             : mandt not null;
  key itempedidouuid    : sysuuid_x16 not null;
  pedidouuid            : sysuuid_x16;
  itemuuid              : sysuuid_x16;
  qtdeitempedido        : zpc_de_quantidade;
  currency              : zpc_de_moeda;
  @Semantics.amount.currencyCode : 'zta_pc_itped_d.currency'
  precounitariosnapshot : zpc_de_preco_unitario;
  @Semantics.amount.currencyCode : 'zta_pc_itped_d.currency'
  valortotal            : zpc_de_valor_total;
  observacao            : zpc_de_observacao;
  include zpc_s_admin_d;
  "%admin"              : include sych_bdl_draft_admin_inc;

}