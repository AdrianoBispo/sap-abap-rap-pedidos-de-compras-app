@EndUserText.label : 'Item do pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_item_ped {

  key client            : abap.clnt not null;
  key item_pedido_uuid  : sysuuid_x16 not null;
  pedido_uuid           : sysuuid_x16;
  item_uuid             : sysuuid_x16;
  qtde_item_pedido      : abap.int4;
  currency              : abap.cuky;
  @Semantics.amount.currencyCode : 'zta_pc_item_ped.currency'
  preco_unitario_snap   : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zta_pc_item_ped.currency'
  valor_total           : abap.curr(15,2);
  observacao            : abap.char(500);
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}
