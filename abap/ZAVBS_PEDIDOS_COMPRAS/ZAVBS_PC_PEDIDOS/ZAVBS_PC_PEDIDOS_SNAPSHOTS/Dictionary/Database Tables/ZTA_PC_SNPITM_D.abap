@EndUserText.label : 'Draft table for entity ZR_PC_PED_ITEM_SNAP'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_snpitm_d {

  key mandt            : mandt not null;
  key snapshotitemuuid : sysuuid_x16 not null;
  pedidouuid           : sysuuid_x16;
  itempedidouuid       : sysuuid_x16;
  itemuuid             : sysuuid_x16;
  include zpc_s_dados_item;
  quantidade           : zpc_de_quantidade;
  currency             : zpc_de_moeda;
  @Semantics.amount.currencyCode : 'zta_pc_snpitm_d.currency'
  precounitario        : zpc_de_preco_unitario;
  @Semantics.amount.currencyCode : 'zta_pc_snpitm_d.currency'
  valortotal           : zpc_de_valor_total;
  include zpc_s_admin_d;
  "%admin"             : include sych_bdl_draft_admin_inc;

}