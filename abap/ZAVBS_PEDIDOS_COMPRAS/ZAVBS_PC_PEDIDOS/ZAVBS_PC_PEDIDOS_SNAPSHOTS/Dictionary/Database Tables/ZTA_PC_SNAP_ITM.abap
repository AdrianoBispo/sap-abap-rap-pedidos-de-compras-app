@EndUserText.label : 'Snapshot dos itens no pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_snap_itm {

  key client             : abap.clnt not null;
  key snapshot_item_uuid : sysuuid_x16 not null;
  pedido_uuid            : sysuuid_x16;
  item_pedido_uuid       : sysuuid_x16;
  item_uuid              : sysuuid_x16;
  include zpc_s_dados_item;
  quantidade             : zpc_de_quantidade;
  currency               : zpc_de_moeda;
  @Semantics.amount.currencyCode : 'zta_pc_snap_itm.currency'
  preco_unitario         : zpc_de_preco_unitario;
  @Semantics.amount.currencyCode : 'zta_pc_snap_itm.currency'
  valor_total            : zpc_de_valor_total;
  include zpc_s_admin;

}