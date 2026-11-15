@EndUserText.label : 'Item do pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_item_ped {

  key client           : abap.clnt not null;
  key item_pedido_uuid : sysuuid_x16 not null;
  pedido_uuid          : sysuuid_x16;
  item_uuid            : sysuuid_x16;
  qtde_item_pedido     : zpc_de_quantidade;
  currency             : zpc_de_moeda;
  @Semantics.amount.currencyCode : 'zta_pc_item_ped.currency'
  preco_unitario_snap  : zpc_de_preco_unitario;
  @Semantics.amount.currencyCode : 'zta_pc_item_ped.currency'
  valor_total          : zpc_de_valor_total;
  observacao           : zpc_de_observacao;
  include zpc_s_admin;

}